#!/usr/bin/env python3
import argparse
import logging
import pathlib
import subprocess
import sys
import time
from utillib import datelib
assert sys.version_info.major >= 3, 'Python 3 required'

PLOT_CMD = (
  pathlib.Path('~/bin/scatterplot.py').expanduser(), '--unix-time', 'x', '--time-unit', 'hr',
  '--point-size', '5', '--y-label', 'Charge (%)',
  '--title', 'Battery charge during last unplugged period'
)
DESCRIPTION = """Filter the battery log for the last full unplugged period.
This will output a tab-delimited record with two fields per line: a unix timestamp and a battery
charge percentage."""


def make_argparser():
  parser = argparse.ArgumentParser(add_help=False, description=DESCRIPTION)
  options = parser.add_argument_group('Options')
  options.add_argument('battery_log', metavar='battery.tsv', nargs='?', type=pathlib.Path,
    default=pathlib.Path('~/aa/computer/logs/battery.tsv').expanduser(),
    help='The battery log. Default: %(default)s')
  options.add_argument('-s', '--start', default='3 days', type=datelib.time_str_to_seconds,
    help='Only examine this much history. Give an amount of time like "10 hours" or "2 days". '
      'Default: %(default)s.')
  options.add_argument('-p', '--plot', action='store_true',
    help='Plot the results with scatterplot.py.')
  options.add_argument('-h', '--help', action='help',
    help='Print this argument help text and exit.')
  logs = parser.add_argument_group('Logging')
  logs.add_argument('-l', '--log', type=argparse.FileType('w'), default=sys.stderr,
    help='Print log messages to this file instead of to stderr. Warning: Will overwrite the file.')
  volume = logs.add_mutually_exclusive_group()
  volume.add_argument('-q', '--quiet', dest='volume', action='store_const', const=logging.CRITICAL,
    default=logging.WARNING)
  volume.add_argument('-v', '--verbose', dest='volume', action='store_const', const=logging.INFO)
  volume.add_argument('-D', '--debug', dest='volume', action='store_const', const=logging.DEBUG)
  return parser


def main(argv):

  parser = make_argparser()
  args = parser.parse_args(argv[1:])

  logging.basicConfig(stream=args.log, level=args.volume, format='%(message)s')

  now = int(time.time())
  start_time = now - args.start
  with args.battery_log.open('r') as battery_file:
    history = find_last_unplugged(list(read_log(battery_file, start_time)))

  if args.plot:
    process = subprocess.Popen(PLOT_CMD, stdin=subprocess.PIPE, encoding='utf8')
    outfile = process.stdin
  else:
    outfile = sys.stdout

  for timestamp, charge_pct in history:
    print(timestamp, round(charge_pct, 2), sep='\t', file=outfile)


def read_log(log_lines, start_time):
  for line_raw in log_lines:
    fields = line_raw.split('\t')
    timestamp = int(fields[0])
    if timestamp < start_time:
      continue
    charge = float(fields[3])
    capacity = float(fields[5])
    charge_pct = 100*charge/capacity
    yield timestamp, charge_pct


def find_last_unplugged(battery_data, margin=5, tolerance=0):
  """Get get a `list` of the data points from the last period of discharge and recharge.
  `margin` is how many points of full charge to include on either side of the unplugged period.
  `tolerance` is how strict to be about when we consider the battery fully charged.
    Give a number of percentage points we can be away from 100%. E.g. `tolerance=0.5` means we
    consider anything at or above 99.5% to be fully charged."""
  last_unplugged = []
  full_pct = 100 - tolerance
  # Go through the data backward, so we can just look for the first time a non-full-charge period
  # appears (to us).
  started = False
  for i in range(len(battery_data)-1, -1, -1):
    timestamp, charge_pct = battery_data[i]
    if started:
      last_unplugged.append((timestamp, charge_pct))
      if charge_pct >= full_pct:
        # We're at the start (chronologically) of the last unplugged period (the end in this loop).
        # Include this and the next few data points.
        end = max(i-margin+1, 0)
        for j in range(i, end, -1):
          last_unplugged.append(battery_data[j])
        break
    elif charge_pct < full_pct:
      # We're at the end (chronologically) of the last unplugged period (the start in this loop).
      started = True
      # Include this and the last few data points.
      end = min(i+margin+1, len(battery_data)-1)
      for j in range(end-1, i-1, -1):
        last_unplugged.append(battery_data[j])
  return reversed(last_unplugged)


def fail(message):
  logging.critical('Error: '+str(message))
  if __name__ == '__main__':
    sys.exit(1)
  else:
    raise Exception(message)


if __name__ == '__main__':
  try:
    sys.exit(main(sys.argv))
  except BrokenPipeError:
    pass
