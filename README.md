# Syslog-Blaster
Test tooling to saturate a Syslog connection using TCP and/or UDP connections.

This repo includes two tools that work together:

genSyslog.pl - 

This tool was created to test maximum throughput on a single connection, or
across multiple connections, when delivering to the Syslog source in 
Cribl Stream, or to any other Syslog destination such as rsyslog, Syslog-NG.

Performance stats are output to STDOUT.

testharness.pl -

This quick-and-dirty 'testharness' invokes a performance test multiple times,
collecting output from each run, and providing an analysis of the top results.


Additional operational details, and configuration settings for each tool, are
found within the tools themselves.

- Michael Donnelly

