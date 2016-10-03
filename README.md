#snort2graphite.pl
Read, parse, and send the contents of snort.stats to a Graphite server

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

###examples:
read /var/log/snort-eth1/snort.stats and send the last line to graphite listening on 127.0.0.1:2003<br>
`./snort2graphite.pl -f /var/log/snort-eth1/snort.stats -s 127.0.0.1:2003`

read /var/log/snort-eth1/snort.stats, send the last line to graphite listening on 192.168.2.2:2003,
and generate some debug output<br>
`./snort2graphite.pl -d -f /var/log/snort-eth1/snort.stats -s 192.168.2.2:2003`

read /var/log/snort-eth0/snort.stats, send the last line to graphite listening on 192.168.2.2:2003,
and add an interface tag of "eth2" into the graphite namespace value<br>
`./snort2graphite.pl -i eth2 -f /var/log/snort-eth2/snort.stats -s 192.168.2.2:2003`


Before this program will work, you need to tell snort to generate a snort.stats file. In your
snort.conf, add a line like this...<br>
`preprocessor perfmonitor: time 60 file /var/log/snort-eth1/snort.stats pktcnt 1000`
<br>
...then restart snort and look for that snort.stats file to be created. You can read more
about Snort's performance stats in the snort manual under Configuring Snort ->
Preprocessors -> Performance Monitor.

I run two snort processes on two different ethernet ports that log to /var/log/snort-eth1 and 
/var/log/snort-eth2 so I have snort2graphite.pl set up to execute from cron every minute with the 
following cron entires:<br>
```
* * * * * /usr/sbin/snort2graphite.pl -d -f /var/log/snort-eth1/snort.stats -i eth1 -s 127.0.0.1:2003 > /var/log/snort2graphite.pl_eth2_cron.log 2>&1
* * * * * /usr/sbin/snort2graphite.pl -d -f /var/log/snort-eth2/snort.stats -i eth2 -s 127.0.0.1:2003 > /var/log/snort2graphite.pl_eth2_cron.log 2>&1
```


The Net::Graphite perl module is required. If you don't have it, do this from your linux command line:<br>
```
perl -MCPAN -e shell
install Net::Graphite
```

