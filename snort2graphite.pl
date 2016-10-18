#!/usr/bin/perl -w
#
# snort2graphite.pl 
# read, parse, and send the contents of snort.stats to graphite
# 2016-10-03 Greg Volk 
# https://github.com/gregvolk/snort2graphite
#
#
# required command line flags are:
# -f <input file> 
# -s <graphiteserver:port>
# optional command line flags are:
# -i <interfacenametag>
# -d = turn on debug data
#
# syntax: 
# ./snort2graphite.pl [-i interfacenametag] [-d] -s <graphiteserver:port> -f <snort.stats-file-location>
#
#
# Before this program will work, you need to tell snort to generate a snort.stats file. In your
# snort.conf, add a line like this...
# preprocessor perfmonitor: time 60 file /var/log/snort-eth1/snort.stats pktcnt 1000 max_file_size 50000
# ...then restart snort and look for that snort.stats file to be created. You can read more
# about Snort's performance stats in the snort manual under Configuring Snort -> 
# Preprocessors -> Performance Monitor
#
#
# The Net::Graphite perl module is required. If you don't have it, do this:
# perl -MCPAN -e shell
# install Net::Graphite
#
#
# example executions: 
# read /var/log/snort-eth1/snort.stats and send the last line to graphite listening on 127.0.0.1:2003
# ./snort2graphite.pl -f /var/log/snort-eth1/snort.stats -s 127.0.0.1:2003
# 
# read /var/log/snort-eth1/snort.stats, send the last line to graphite listening on 192.168.2.2:2003,
# and generate some debug output
# ./snort2graphite.pl -d -f /var/log/snort-eth1/snort.stats -s 192.168.2.2:2003
#
# read /var/log/snort-eth0/snort.stats, send the last line to graphite listening on 192.168.2.2:2003,
# and add an interface tag of "eth2" into the graphite namespace value
# ./snort2graphite.pl -i eth2 -f /var/log/snort-eth2/snort.stats -s 192.168.2.2:2003
#
# I run snort on two ethernet ports so I have snort2graphite.pl set up to execute from cron every 
# minute with the following cron entires:
# * * * * * /usr/sbin/snort2graphite.pl -d -f /var/log/snort-eth1/snort.stats -i eth1 -s 127.0.0.1:2003 > /var/log/snort2graphite.pl_eth2_cron.log 2>&1
# * * * * * /usr/sbin/snort2graphite.pl -d -f /var/log/snort-eth2/snort.stats -i eth2 -s 127.0.0.1:2003 > /var/log/snort2graphite.pl_eth2_cron.log 2>&1
# 
#
#


use strict;
use Getopt::Std;
use Sys::Hostname;
use Net::Graphite;

# declare some stuff
my ($time,$value,$modfield,$interface,$FH,@input,$field,$line,@fields,%csvhash,@a,
    $debug,$sendcount,$linecount);
my %options;
my $hostname = hostname();

# get some command line args
getopts("df:s:i:",\%options);

# sanity check the required args
unless (defined $options{f}) { die "-f <snort.stats file location> required\n"; }
my $snortstatsfile = $options{f};
unless (defined $options{s}) { die "-s <graphiteserver:port> required\n"; }
my $graphiteserver = $options{s};

# assign optional interface tag
if(defined $options{i}) {
  $interface = "snort-$options{i}";
} else {
  $interface = "snort";
}

# check for debug flag
if(defined $options{d}) { $debug = 1; }

# split the graphite server name|ip:port components out
@a = split ":",$graphiteserver;

my $graphite;                           #use this for object
my $graphitehost = $a[0];		#ip/name of graphite server
my $graphiteport = $a[1];		#graphite port
my $graphiteproto = "tcp";              #graphite protocol
my $graphitetrace = 0;                  #send data to STDERR for debug?
my $graphitetimeout = 5;                #socket connect timeout in seconds
my $graphiteff = 0;                     #fire & forget, if true, ignore sending errors
my $graphiteconerr = 1;                 #if true, forward connect error to caller
my $graphitens;				#use this for building the namespace var

# open the graphite socket
$graphite = Net::Graphite->new(
  host                  => $graphitehost,
  port                  => $graphiteport,
  trace                 => $graphitetrace,
  proto                 => $graphiteproto,
  timeout               => $graphitetimeout,
  fire_and_forget       => $graphiteff,
  return_connect_error  => $graphiteconerr
);

# sanity check the socket
unless($graphite->connect) { die "graphite connect error to $graphiteserver $!\n"; }

if($debug) { print localtime().":successfully opened graphite socket ($graphite)\n"; }

# does the snort.stats file exist?
unless (-e $snortstatsfile) { die "$snortstatsfile does not exist!\n"; }

# open the snort stats file, read it, close it
open $FH,"<",$snortstatsfile or die "cannot open $snortstatsfile: $!\n";
@input = <$FH>;
close $FH;

# iterate over each line until we find the csv header
foreach $line (@input) {
  $linecount++;
  chomp $line;
  if($line =~ /^#time/) { # this is a lame check for the header
    $line =~ s/^#//g;     # get rid of the leading #
    @fields = split( /,/, $line ); # assign fields array to csv header
    last; # don't bother with further processing since we have the header now
  }
}

if($debug) { print localtime().":found $#fields fields in csv header after $linecount lines of data\n"; }

# store the last (most recent) line of the stats file in a hash table keyed 
# with the fields from above
chomp $input[$#input];
@csvhash{ @fields } = split( /,/, $input[$#input]);

# iterate over each field from the header we found above
foreach $field (@fields) {
  # get the data, store in 'value'
  $value = $csvhash{$field};

  # create a copy of the field name so we can modify it to be graphite namespace compliant
  $modfield = $field;

  # replace periods with hyphens because periods are a graphite namespace delimiter
  $modfield =~ s/\./\-/g;
  # replace :: with hyphens because colons are not allowed in graphite's namespace
  $modfield =~ s/::/\-/g;
  # replace brackets with hyphens because brackets are not allowed in graphite's namespace
  $modfield =~ s/\[//g;
  $modfield =~ s/\]//g;

  # assemble the full namespace value, example = myhost.snort-eth1.alerts_per_second
  $graphitens = "$hostname.$interface.$modfield";

  # get the epoch time stamp from the csv record
  $time = $csvhash{time};

  if($debug) { print localtime().":graphite->send($graphitens,$value,$time)\n"; }

  # keep track of how many graphite sends we are doing
  $sendcount++;

  # send the data to graphite
  $graphite->send(
    path => "$graphitens",
    value => "$value",
    time => $time,
  )
}

if($debug) { print localtime().":done! We sent a total of $sendcount variables to $graphiteserver.\n"; }
