#!/usr/bin/perl -w

#
# This quick-and-dirty 'testharness' invokes a performance test multiple times,
# collecting output from each run, and providing an analysis of the top results.
#
# This was created specifically for real-world throughput testing using the 
# genSyslog.pl script.  That script's final line of output shows the
# overall throughput of that specific run.
#
# To use configure the test harness, 
#  1) Configure genSyslog.pl _first_, and run it once manually to test
#  2) Review and edit the settings listed below, 
#  3) run: 
#        #   ./testharness.pl
#  4) output is to the screen, next step is up to you.


use strict;

#
### SETTINGS 
#
my $n = 10;	# number of times to run
my $x = 3;	# return the top X results out of all runs
my $w = 1; 	# Wait this many seconds between runs
my $cmd = './genSyslog.pl | tail -1';  # The command being executed
#
######
#

my $i=0;
my @results;
while ($i++ < $n)
{
	print "####\nPass $i\n####\n";
	my $result = `$cmd`;
	$result =~s/.*: //;	# strip leader
	$result =~s/ .*//;	# strip trailing text
	$result =~s/,//g;	# remove commas from test
	print "Result: $result\n";
	push(@results, $result);

	sleep($w) unless ($i==$n);
}

my @sorted = sort { $b <=> $a } @results;

print "Top $x results\n";
foreach (@sorted[0 .. ($x-1)])
{ print "$_\n"; }
