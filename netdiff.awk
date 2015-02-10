# Usage: netstat -A inet,inet6 -W --program | awk -v ignore_ports=http,https -f netdiff.awk
# This will filter out netstat lines that either match an ignored parameter or don't match a
# watched parameter. The output will be 4 tab-delimited columns: program, pid, destination port,
# and destination ip (or domain name). If you give both ignore and watch parameters, only the watch
# ones will be used (the mode will be "ignore unless it meets a watch critera").

BEGIN {
  OFS="\t";
  # Turn command line options (set with -v) into arrays.
  split(watch_ports,  wports, ",");
  split(ignore_ports, iports, ",");
  split(watch_progs,  wprogs, ",");
  split(ignore_progs, iprogs, ",");
  split(watch_procs,  wprocs, ",");
  split(ignore_procs, iprocs, ",");
}

NF == 7 && $6 == "ESTABLISHED" {
  # Parse fields
  len = split($5, fields, ":");
  port = fields[len];
  ## Get ip from ip:port, dealing with colon-delimited ipv6 addresses (join all fields but the last
  ## with ":"). In python: ip = ':'.join(fields[:len-1])
  ip = fields[1];
  for (i in fields) {
    if (i > 1 && i < len) {
      ip = ip":"fields[i];
    }
  }
  split($7, fields, "/");
  proc = fields[1];
  prog = fields[2];
  # Filter
  if (watch_ports || watch_progs || watch_procs) {
    passed = 0;
  } else {
    passed = 1;
  }
  ## Filter out ignored connections
  for (i in iports) {
    if (port == iports[i]) passed = 0;
  }
  for (i in iprogs) {
    if (prog == iprogs[i]) passed = 0;
  }
  for (i in iprocs) {
    if (proc == iprocs[i]) passed = 0;
  }
  ## Filter in watched connections
  for (i in wports) {
    if (port == wports[i]) passed = 1;
  }
  for (i in wprogs) {
    if (prog == wprogs[i]) passed = 1;
  }
  for (i in wprocs) {
    if (proc == wprocs[i]) passed = 1;
  }
  # print
  if (passed) print prog, proc, port, ip;
}