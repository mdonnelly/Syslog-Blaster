# Syslog-Blaster

**Syslog-Blaster** is a set of tooling to test throughput when delivering to Syslog destinations.

The tool does this by saturating the destination using one or more TCP connections; measuring throughput.

UDP is also supported, though (due to the nature of UDP) the tool will send as quickly as possible.  With UDP testing, one should compare the number of events sent against the number of events received.

This repo includes two tools that work together:

**genSyslog.pl**

This tool was created to test maximum throughput on a single connection, or  
across multiple connections, when delivering to the Syslog source in  
Cribl Stream, or to any other Syslog destination such as rsyslog, Syslog-NG.

Performance stats are output to STDOUT.

**testharness.pl**

This quick-and-dirty 'testharness' invokes a performance test multiple times,  
collecting output from each run, and providing an analysis of the top results.



**Configuration & Operation:**

Configuration settings for each tool, and additional operational details, are found within the tools themselves.

# Download the .pl files from this repo
# Edit genSyslog.pl, and configure the Settings section
# Run genSyslog.pl to verify it is working as expected

When you are ready to run multiple passes,
# Edit testharness.pl, and configure the Settings section
# Run testharness.pl

*Author: Michael Donnelly*