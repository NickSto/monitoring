#!/usr/bin/env python3
import argparse
import logging
import os
import pathlib
import subprocess
import sys
import time
from utillib import simplewrap

DESCRIPTION = """Log the size of a file.
This outputs a single line with 4-6 tab-delimited columns:
1. The unix timestamp of when this script was executed.
2. The path of the target file, as given to this script. If --no-path is given, this column will \
be ".".
3. The size of the target file in bytes.
4. The rate of growth of the file, in bytes per second. This value is only given when the previous \
size is known, i.e. when a non-empty --outfile is provided. Otherwise this column will be ".".
5. The number of lines in the file, as counted by `wc`. This column is only included when the \
--lines flag is given. Otherwise, the entire column is omitted.
6. The rate of growth of the file, in lines per second. This column is only included when the \
--lines flag is given AND the previous line count is known."""
EPILOG = """Note: If --lines is given, this will count both bytes and lines with `wc`. Otherwise, \
it will just use `os.path.getsize()`."""


def make_argparser():
  parser = argparse.ArgumentParser(
    add_help=False, formatter_class=argparse.RawDescriptionHelpFormatter,
    description=simplewrap.wrap(DESCRIPTION, lspace=3, indent=-3),
    epilog=simplewrap.wrap(EPILOG)
  )
  options = parser.add_argument_group('Options')
  options.add_argument('target', type=pathlib.Path,
    help='The file to watch.')
  options.add_argument('-l', '--lines', action='store_true',
    help='Output the number of lines in addition to the number of bytes.')
  options.add_argument('-o', '--outfile', type=pathlib.Path,
    help='Write output to this file instead of stdout. This will append to the target file, not '
      'overwrite it. Giving this option means this script will also read this file to get the '
      'most recent size, calculate a growth rate, and include it as an output field.')
  options.add_argument('-P', '--no-path', dest='path', action='store_false', default=True,
    help="Omit the path from the output. This just replaces the path with '.' and doesn't affect "
      'the number of output columns.')
  options.add_argument('-w', '--watch', action='store_true',
    help='Keep running, watching the file and printing a line every --interval minutes. If the '
      'target file does not exist when this checks, it will not output anything and wait again.')
  options.add_argument('-i', '--interval', type=float, default=1,
    help='How often to check the file size, in minutes. Default: %(default)s')
  options.add_argument('-h', '--help', action='help',
    help='Print this argument help text and exit.')
  logs = parser.add_argument_group('Logging')
  logs.add_argument('-L', '--log', type=argparse.FileType('w'), default=sys.stderr,
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

  loop = 0
  last_timestamp, last_bytes, last_lines = None, None, None

  while True:

    loop += 1
    if args.watch and loop > 1:
      try:
        time.sleep(args.interval*60)
      except KeyboardInterrupt:
        break

    if not args.watch and args.outfile and args.outfile.is_file():
      try:
        last_timestamp, last_bytes, last_lines = read_last_log(args.outfile)
      except ParseError:
        pass

    if not args.target.is_file():
      if args.watch:
        continue
      else:
        fail('Error: Target file not found or is not a regular file.')

    fields = []

    timestamp = int(time.time())
    fields.append(timestamp)

    if args.path:
      fields.append(args.target)
    else:
      fields.append('.')

    # Get the file size.
    if args.lines:
      size_lines, size_words, size_bytes = get_wc_size(args.target)
      fields.extend([size_bytes, '.', size_lines])
    else:
      size_bytes = os.path.getsize(args.target)
      size_lines = None
      fields.append(size_bytes)

    # Get the change in size, if we got the last counts from a log file.
    if last_timestamp and last_timestamp != timestamp:
      elapsed = timestamp - last_timestamp
      bytes_per_sec = (size_bytes - last_bytes) / elapsed
      bytes_per_sec_str = f'{bytes_per_sec:0.5f}'
      if len(fields) == 3:
        fields.append(bytes_per_sec_str)
      elif len(fields) == 5:
        fields[3] = bytes_per_sec_str
      if size_lines is not None and last_lines is not None:
        lines_per_sec = (size_lines - last_lines) / elapsed
        if len(fields) == 5:
          fields.append(f'{lines_per_sec:0.5f}')

    # Write the output.
    if args.outfile:
      outstream = args.outfile.open('a')
    else:
      outstream = sys.stdout
    print(*fields, sep='\t', file=outstream)
    if outstream is not sys.stdout:
      outstream.close()

    last_timestamp, last_bytes, last_lines = timestamp, size_bytes, size_lines

    if not args.watch:
      break


def read_last_log(log_path):
  empty = True
  # Read file to get the last line.
  with log_path.open('r') as log_file:
    for line_raw in log_file:
      fields = line_raw.rstrip('\r\n').split('\t')
      empty = False
  if empty:
    raise ParseError('Existing log file is empty.') from None
  # Parse last line.
  try:
    timestamp = int(fields[0])
  except ValueError:
    raise ParseError(f'Bad timestamp in existing log file: {fields[0]!r}') from None
  try:
    size_bytes = int(fields[2])
  except IndexError:
    raise ParseError(
      f'No bytes column found in existing log (saw {len(fields)} columns in last line)'
    ) from None
  except ValueError:
    raise ParseError(f'Bad final bytes integer in existing log: {fields[2]!r}') from None
  try:
    size_lines = int(fields[4])
  except IndexError:
    # The log didn't include line counts, which is valid.
    size_lines = None
  except ValueError:
    raise ParseError(f'Bad final lines integer in existing log: {fields[4]!r}') from None
  return timestamp, size_bytes, size_lines


def get_wc_size(target_path):
  result = subprocess.run(
    ['wc', target_path], text=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE
  )
  fields = result.stdout.split()
  try:
    lines_str, words_str, bytes_str, path = fields
  except ValueError:
    raise ParseError(f'Received the wrong number of fields from wc: {result.stdout!r}') from None
  try:
    return int(lines_str), int(words_str), int(bytes_str)
  except ValueError:
    raise ParseError(f'Error parsing integers from wc output: {result.stdout!r}') from None


class ParseError(RuntimeError):
  pass


def fail(message):
  logging.critical(f'Error: {message}')
  if __name__ == '__main__':
    sys.exit(1)
  else:
    raise Exception(message)


if __name__ == '__main__':
  try:
    sys.exit(main(sys.argv))
  except BrokenPipeError:
    pass
