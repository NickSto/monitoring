# Usage: $ lsof -i -n -F pcnTP | awk -v ignore_ports=http,https -f netdiff.awk
# This will parse lsof output and filter out connections that either match an ignored parameter or
# don't match a watched parameter.
# The output will be 5 tab-delimited columns:
#   program, pid, destination port, destination ip, protocol, and connection state.
# Note: If there is no destination address (occurs when the process is only LISTENing), the port
# listed will be the source port and the destination ip will be empty. Empty fields are shown as "-".
# You can omit the -n option from lsof to get domain names instead of ip addresses.
# If multiple watch parameters are given, it will print all the connections that match *any* of the
# watch parameters. If you give both ignore and watch parameters, only the watch ones will be used
# (the mode will be "ignore unless it meets a watch critera").

BEGIN {
  OFS="\t"
  # Turn command line options (set with -v) into arrays.
  split(watch_ports,  wports, ",")
  split(ignore_ports, iports, ",")
  split(watch_progs,  wprogs, ",")
  split(ignore_progs, iprogs, ",")
  split(watch_procs,  wprocs, ",")
  split(ignore_procs, iprocs, ",")
  split(watch_dests,  wdests, ",")
  split(ignore_dests, idests, ",")
  split(watch_states,  wstates, ",")
  split(ignore_states, istates, ",")
}

# Parse an lsof -F output line (the first character is the field identifier).
{
  field = substr($0, 1, 1)
  value = substr($0, 2)
}

# The process id field.
field == "p" {
  # Print out the previous connection, if there was one.
  if (pid) {
    output()
  }
  pid = value
  first_connection = "true"
}
# The command name field.
field == "c" {
  prog = value
}
# The connection statistic field.
field == "T" {
  split(value, fields, "=")
  # We're only interested in the connection state value.
  if (fields[1] == "ST") {
    state = fields[2]
  }
}
# The protocol field.
field == "P" {
  # This is the first field in a connection listing.
  # Print out the previous connection for this process, if there was one.
  if (! first_connection) {
    output()
  }
  first_connection = 0
  protocol = value
}
# The network source/destination field.
field == "n" {
  n_ends = split(value, fields, "->")
  destport = fields[n_ends]
  len = split(destport, fields, ":")
  port = fields[len]
  if (n_ends == 1) {
    dest = "-"
  } else {
    # Stitch back together colon-delimited ipv6 addresseses (join all fields but the last with ":").
    # In python: dest = ':'.join(fields[:len-1]).
    dest = fields[1]
    for (i = 2; i < len; i++) {
      dest = dest":"fields[i]
    }
    # ipv6 addresses are enclosed in [brackets]. Remove them.
    if (substr(dest, 1, 1) == "[" && substr(dest, length(dest), 1) == "]") {
      dest = substr(dest, 2, length(dest)-2)
    }
  }
}

# Return the value, or "-" if the value is false.
function value_or_dash(value) {
  if (value) {
    return value
  } else {
    return "-"
  }
}

# Determine if we've passed the filters.
function passed_filters() {
  if (watch_ports || watch_progs || watch_procs || watch_dests || watch_states) {
    passed = 0
  } else {
    passed = 1
  }
  # Filter out ignored connections
  for (i in iprogs) {
    if (prog == iprogs[i]) passed = 0
  }
  for (i in ipids) {
    if (pid == ipids[i]) passed = 0
  }
  for (i in iports) {
    if (port == iports[i]) passed = 0;
  }
  for (i in idests) {
    if (dest == idests[i]) passed = 0
  }
  for (i in istates) {
    if (state == istates[i]) passed = 0
  }
  # Filter in watched connections
  for (i in wprogs) {
    if (prog == wprogs[i]) passed = 1
  }
  for (i in wpids) {
    if (pid == wpids[i]) passed = 1
  }
  for (i in wports) {
    if (port == wports[i]) passed = 1
  }
  for (i in wdests) {
    if (dest == wdests[i]) passed = 1
  }
  for (i in wstates) {
    if (state == wstates[i]) passed = 1
  }
  return passed
}

# Format and print the current connection, if it passes the filters.
function output() {
  if (protocol == "UDP") {
    state = "-"
  }
  if (! passed_filters()) {
    return
  }
  prog = value_or_dash(prog)
  pid = value_or_dash(pid)
  port = value_or_dash(port)
  dest = value_or_dash(dest)
  protocol = value_or_dash(protocol)
  state = value_or_dash(state)
  print prog, pid, port, dest, protocol, state
}

# Print the last connection.
END {
  output()
}
