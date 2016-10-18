#snort2graphite.pl
Read, parse, and send the contents of snort.stats to a Graphite server.<br>
Snort IDS/IPS can be configured to generate a rich set of metrics about network 
traffic. Presently there are more than 130 metrics available. Snort2graphite 
will pick up the most recent data from your snort.stats file and send all the 
metrics into Graphite.<br>
Updates at https://github.com/gregvolk/snort2graphite


###required command line flags are:
```
-f <input file>
-s <graphiteserver:port>
```

###optional command line flags are:
```
-i <interfacenametag>
-d = turn on debug output
```

###syntax:
`./snort2graphite.pl [-i interfacenametag] [-d] -s <graphiteserver:port> -f <snort.stats-file-location>`


Before this program will work, you need to tell snort to generate a snort.stats file. In your
snort.conf, add a line like this...<br>

`preprocessor perfmonitor: time 60 file /var/log/snort-eth1/snort.stats pktcnt 1000 max_file_size 50000`
<br>

...then restart snort and look for that snort.stats file to be created. You can read more
about Snort's performance stats in the snort manual under Configuring Snort -> Preprocessors -> 
Performance Monitor.
<br>

The Net::Graphite perl module is required. If you don't have it, do this from your linux command line:<br>
```
perl -MCPAN -e shell
install Net::Graphite
```

###example executions:
read /var/log/snort-eth1/snort.stats and send the last line to graphite listening on 127.0.0.1:2003<br>
`./snort2graphite.pl -f /var/log/snort-eth1/snort.stats -s 127.0.0.1:2003`

read /var/log/snort-eth1/snort.stats, send the last line to graphite listening on 192.168.2.2:2003,
and generate some debug output<br>
`./snort2graphite.pl -d -f /var/log/snort-eth1/snort.stats -s 192.168.2.2:2003`

read /var/log/snort-eth2/snort.stats, send the last line to graphite listening on 192.168.2.2:2003,
and add an interface tag of "eth2" into the graphite namespace value<br>
`./snort2graphite.pl -i eth2 -f /var/log/snort-eth2/snort.stats -s 192.168.2.2:2003`

I run two snort processes on two different ethernet ports that log to /var/log/snort-eth1 and 
/var/log/snort-eth2 so I have snort2graphite.pl set up to execute from cron every minute with the 
following cron entires:<br>
```
* * * * * /usr/sbin/snort2graphite.pl -d -f /var/log/snort-eth1/snort.stats -i eth1 -s 127.0.0.1:2003 > /var/log/snort2graphite.pl_eth1_cron.log 2>&1
* * * * * /usr/sbin/snort2graphite.pl -d -f /var/log/snort-eth2/snort.stats -i eth2 -s 127.0.0.1:2003 > /var/log/snort2graphite.pl_eth2_cron.log 2>&1
```

###debug output:
If you are having trouble making this work, try calling snort2graphite.pl with the -d flag. 
You should get some debug output similar to what appears below.
```
Tue Oct 18 09:14:01 2016:successfully opened graphite socket (Net::Graphite=HASH(0x1b28568))
Tue Oct 18 09:14:01 2016:found 131 fields in csv header after 2 lines of data
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.time,1476800019,1476800019)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.pkt_drop_percent,0.000,1476800019)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.wire_mbits_per_sec-realtime,0.425,1476800019)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.kpackets_wire_per_sec-realtime,0.093,1476800019)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.avg_bytes_per_wire_packet,572,1476800019)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.patmatch_percent,87.579,1476800019)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.syns_per_second,3.649,1476800019)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.synacks_per_second,3.666,1476800019)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.new_sessions_per_second,3.616,1476800019)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.deleted_sessions_per_second,2.946,1476800019)
...
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.total_sessions,913,1476800019)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.max_sessions,949,1476800019)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.stream_flushes_per_second,6.445,1476800019)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.total_injected_packets,0,1476800199)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.frag3_mem_in_use,0,1476800199)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.stream5_mem_in_use,634745,1476800199)
Tue Oct 18 09:14:01 2016:graphite->send(myhost.snort-eth1.total_alerts_per_second,0.033,1476800199)
Tue Oct 18 09:14:01 2016:done! We sent a total of 131 variables to 127.0.0.1:2003.
```

