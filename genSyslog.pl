#!/usr/bin/perl -w

#
# This tool was created to test maximum throughput on a single connection, or
# across multiple connections, when delivering to the Syslog source in 
# Cribl Stream.   
#
# The tool supports delivery to Cribl Stream using
#    * zero, one, or two TCP connections
#    * zero or one UDP connections
#
# Uses include testing of:
#    * potential improvements regarding TCP Pinning 
#         - use a single TCP connection, no UDP
#    * pack performance
#         - establish a baseline where Stream sends to passthrough + dest
#         - measure again with Syslog sending through pack + dest
#         - Compare before and after
#    * network performance
#    * OS tuning to prevent packet loss
#         - use a single UDP connection, no TCP
#         - configure $count with a specific number of events, set $runtime=0
#         - Use Cribl dashboard to compare # events received with #count
#
# To use configure the tool,
#  1) WHERE TO RUN:
#	1a) If testing to a Cribl Cloud, Install and run this tool from an 
#	    EC2 system running in the same region as Cribl Cloud Workers.
#	1b) If testing in Docker, Install and run this tool from a dedicated
#	    container running on the same host
#  2) Perform a one-time installation of the Perl libraries.  
#     The instructions here are for a Ubuntu Linux VM, edit as needed
#       sudo apt-get install cpanminus
#       sudo cpanm install Log::Syslog::Fast
#  3) Configure your Cribl Stream worker to listen on Syslog ports, deploy
#  4) Review and edit SETTINGS section below.  For an initial run, use
#     $count = 100       -and-        $runtime=30
#  5) Revise $count and $runtime as needed
#  	  - for a fixed duration run, set $count = 0 and $runtime as desired
#  	  - for a set number of events, set $runtime=0 and $count as desired
#  6) Run the tool
#  7) Optional: For multiple test runs, use testharness.pl

use strict;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
	                    clock_gettime clock_getres clock_nanosleep clock
			                        stat lstat utime);
use Log::Syslog::Fast ':all';

#
##### SETTINGS
#
my $loghost='default.main.eloquent-lumiere-gzz5b98.cribl.cloud';  	# EDIT TO YOUR INSTANCE!
my $runtime=30;	# max seconds to run.  Set to 0 for unlimited.
my $count=0;	# max iterations to send.  Set to 0 for unlimited.
my $sendUDP=0;  # set to 0 to disable, 1 to enable
my $sendTCP=1;  # set to 0, 1, or 2 TCP threads for sending.
my $appname;	# defaults to 'datatest'
my $hostname = 'firewall1';	# defaults to 'myhost'
my $use_rfc_5424=0;	#Set to 1 to enable RFC5424 format, 0 to disable
my $udpPort = 9514;	# match this port to your syslog source
my $tcpPort1 = 9514;	# match this port to your syslog source
my $tcpPort2 = 9514;	# match this port to your syslog source

my $msg;        # Enable one of the message formats below.

# PAN THREAT
#$msg = '1,2021/07/20 23:59:02,1234567890,THREAT,url,1,2021/07/20 23:59:02,10.14.6.57,206.169.145.222,204.107.141.240,206.169.145.222,RFC1918 to Internet,,,web-browsing,vsys1,Trust,Untrust,ae1.902,ae1.1000,LoggingToPanorama,2021/07/20 23:59:02,549835,1,58102,80,10325,80,0x408000,tcp,alert,"cribl.io/download",(9999),not-defined,informational,client-to-server,1247301142,0x0,10.0.0.0-10.255.255.255,United States,0,text/html';

# PAN TRAFFIC
$msg = '1,2018/09/20 13:03:58,44A1B3FC68F5304,TRAFFIC,end,2049,2018/09/20 13:03:58,34.217.108.226,10.0.0.102,34.217.108.226,10.0.2.65,splunk,,,incomplete,vsys1,untrusted,trusted,ethernet1/3,ethernet1/2,log-forwarding-default,2018/09/20 13:03:58,574326,1,53722,8088,53722,8088,0x400064,tcp,allow,296,296,0,4,2018/09/20 13:03:45,7,any,0,730277,0x0,United States,10.0.0.0-10.255.255.255,0,4,0,aged-out,0,0,0,0,,PA-VM,from-policy,,,0,,0,,N/A,0,0,0,0';

# Corelight
# $msg = '{"_path":"conn","_system_name":"ip-172-16-53-100.us-east-2.compute.internal","_write_ts":"2023-05-06T08:38:58.385577Z","ts":"2023-05-06T08:38:58.383864Z","uid":"CtVxxE3smYEtZpQBlf","id.orig_h":"157.55.39.32","id.orig_p":25408,"id.resp_h":"198.71.247.91","id.resp_p":443,"proto":"tcp","duration":0.0008111000061035156,"orig_bytes":0,"resp_bytes":0,"conn_state":"REJ","local_orig":false,"local_resp":false,"missed_bytes":0,"history":"Sr","orig_pkts":1,"orig_ip_bytes":48,"resp_pkts":1,"resp_ip_bytes":40,"tunnel_parents":["CfbukZ3Nhg6McNWQn6"],"orig_cc":"US","resp_cc":"US","spcap.url":"https://localhost/spcap/v1/?uid=CtVxxE3smYEtZpQBlf","spcap.rule":2,"spcap.trigger":"all-unencrypted","corelight_shunted":false,"orig_l2_addr":"64:9e:f3:be:db:66","resp_l2_addr":"00:16:3c:f1:fd:6d","community_id":"1:IXVNH/Omr6aWHMvW9Qyw+8TjWsM="}';

# Cisco ASA
# $msg = '%ASA-session-3-106102: access-list dev_inward_client permitted udp for user redacted outside/10.123.123.20(49721) -> inside/10.223.223.40(53) hit-cnt 1 first hit [0x3c8b88c1, 0xbee595c3]';


#
##### END SETTINGS
#

$appname = 'datatest' unless ($appname);
$hostname = 'myhost' unless ($hostname);

my $udplogger = Log::Syslog::Fast->new(LOG_UDP, $loghost, $udpPort, LOG_LOCAL0, LOG_INFO, $hostname, $appname) if ($sendUDP);

my $tcplogger1 = Log::Syslog::Fast->new(LOG_TCP, $loghost, 9514, LOG_LOCAL0, LOG_INFO, $hostname, $appname) if ($sendTCP);

my $tcplogger2 = Log::Syslog::Fast->new(LOG_TCP, $loghost, 9514, LOG_LOCAL0, LOG_INFO, $hostname, $appname) if ($sendTCP>1);

if ($sendUDP) {
	$udplogger->set_format(LOG_RFC3164);
	$udplogger->set_format(LOG_RFC5424) if ($use_rfc_5424);
}
if ($sendTCP) {
	$tcplogger1->set_format(LOG_RFC3164);
	$tcplogger1->set_format(LOG_RFC5424) if ($use_rfc_5424);
}
if ($sendTCP>1)
{
	$tcplogger2->set_format(LOG_RFC3164);
	$tcplogger2->set_format(LOG_RFC5424) if ($use_rfc_5424);
}

my $i=0;
my $logopt = '';
my $elapsed = 0;
my $start=Time::HiRes::time();

print "Sending to $loghost: \n";
print "  - via UDP\n" if ($sendUDP);
print "  - via TCP on one connection\n" if ($sendTCP==1);
print "  - via TCP on two connections\n" if ($sendTCP==2);

if ($runtime && $count)
{
	print "Sending events for $count iterations, or $runtime seconds, whichever is first\n";
} elsif ($runtime) {
	print "Sending events for $runtime seconds\n";
} elsif ($count) {
	print "Sending events for $count iterations\n";
}

unless ($runtime || $count) {
	print 'Either $runtime or $count must be set for the program to execute' . "\n";
	exit 1;
}

while ( ($runtime==0 || $elapsed < $runtime) && ($count==0 || $i < $count)) 
{
	$i++;
	#	$udplogger->send("UDP test $i - A\n");
	#	$udplogger->send("UDP test $i - B\n");
	#                  appname,srcip,srcport,destip,destport,proto,bytes,version,appname,elapsedTime
	$udplogger->send("$msg\n") if $sendUDP;
	$tcplogger1->send("$msg\n") if $sendTCP;
	$tcplogger2->send("$msg\n") if $sendTCP>1;
	$elapsed = Time::HiRes::time()-$start;
}

# Wrap-up and reporting of results

my $numsent = 0;
$numsent += $i if $sendUDP;
$numsent += $i*$sendTCP if $sendTCP;
print "\n";
print "Sent $i syslog events via UDP\n" if $sendUDP;
print "Sent $i syslog events via TCP on one connection\n" if $sendTCP==1;
print "Sent $i syslog events per connection via TCP on $sendTCP connections\n" if $sendTCP>1;
print "Total events sent: $numsent\n\n";

my $rate = commify( sprintf("%i",$numsent/$elapsed));
printf ("Elapsed time: %.3f seconds\n", $elapsed);
print "Delivery rate: $rate events per second\n";
exit;


sub commify {
	my $text = reverse $_[0];
	$text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
	return scalar reverse $text;
}
