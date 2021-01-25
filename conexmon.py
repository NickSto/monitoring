#!/usr/bin/env python3
import argparse
import logging
import subprocess
import sys
import time
assert sys.version_info.major >= 3, 'Python 3 required'

DEFAULT_EXCLUDES = 'firefox,chrome,dropbox,Code42Service'
DESCRIPTION = """Show info on each network connection and the process making it by filtering the
output of netdiff.sh and cross-referencing it with `ps aux`."""


def make_argparser():
  parser = argparse.ArgumentParser(add_help=False, description=DESCRIPTION)
  options = parser.add_argument_group('Options')
  options.add_argument('-a', '--nargs', type=int, default=2,
    help='The number of command line arguments to include in the output (including the command '
      'itself (ARGV[0])). Default: %(default)s')
  options.add_argument('-n', '--netdiff', action='store_true',
    help='Run the netdiff command internally rather than acting as a filter to pipe it into.')
  options.add_argument('-x', '--excludes', default=DEFAULT_EXCLUDES,
    help='Tell netdiff.sh to exclude (-C) this command. Give a comma-delimited list. '
      'Default: %(default)s')
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

  if args.netdiff:
    process = run_netdiff(args.excludes)
    netdiff_output = process.stdout
  else:
    netdiff_output = sys.stdin

  header = True
  update_lines = []
  for line_raw in netdiff_output:
    if header:
      header = False
    elif line_raw.startswith('- '):
      pass
    elif line_raw.startswith('+ '):
      update_lines.append(line_raw)
    elif line_raw == '--------------\n':
      now = round(time.time())
      for conex_data in parse_lines(update_lines):
        print(now, *format_output(*conex_data, nargs=args.nargs), sep='\t')
      update_lines = []
    else:
      logging.warning(f'Warning: Unrecognized line {line_raw}')


def run_netdiff(excludes):
  if excludes:
    exclude_args = ['-C', excludes]
  else:
    exclude_args = []
  command = ['sudo', 'netdiff.sh', '-i', *exclude_args]
  return subprocess.Popen(command, encoding='utf8', stdout=subprocess.PIPE)


def parse_lines(lines):
  result = subprocess.run(('ps', 'aux'), encoding='utf8', stdout=subprocess.PIPE)
  ps_data = parse_ps(result.stdout.splitlines())
  for line_raw in lines:
    command, pid, port, destination = parse_line(line_raw)
    try:
      proc_info = ps_data[pid]
    except KeyError:
      logging.warning(f'Warning: Process {pid} not found.')
      continue
    cmdline = proc_info[-1]
    if cmdline[0] != command:
      logging.info(
        f"Info: Command name given by lsof ({command}) doesn't match one from ps ({cmdline[0]})."
      )
    yield proc_info, command, destination, port


def parse_line(line_raw):
    fields = line_raw[2:].split('\t')
    command, pid, port, destination, *rest = fields
    return command, pid, port, destination


def parse_ps(ps_output):
  ps_data = {}
  for line_raw in ps_output:
    try:
      user, pid, cpu, mem, vsz, rss, tty, stat, start, time, *cmdline = line_raw.rstrip('\r\n').split()
    except ValueError:
      fail(f'ValueError from this line: {line_raw}')
    ps_data[pid] = (user, cpu, mem, vsz, rss, tty, stat, start, time, cmdline)
  return ps_data


def format_output(proc_info, command, destination, port, nargs=2):
  user, cpu, mem, vsz, rss, tty, stat, start, time, cmdline = proc_info
  return [command, user, destination, port] + cmdline[:nargs]


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
