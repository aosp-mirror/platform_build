#!/usr/bin/python

"""Parse and check syntax errors of a given OWNERS file."""

import argparse
import re
import sys
import urllib
import urllib2

parser = argparse.ArgumentParser(description='Check OWNERS file syntax')
parser.add_argument('-v', '--verbose', dest='verbose',
                    action='store_true', default=False,
                    help='Verbose output to debug')
parser.add_argument('-c', '--check_address', dest='check_address',
                    action='store_true', default=False,
                    help='Check email addresses')
parser.add_argument(dest='owners', metavar='OWNERS', nargs='+',
                    help='Path to OWNERS file')
args = parser.parse_args()

gerrit_server = 'https://android-review.googlesource.com'
checked_addresses = {}


def echo(msg):
  if args.verbose:
    print msg


def find_address(address):
  if address not in checked_addresses:
    request = (gerrit_server + '/accounts/?n=1&q=email:'
               + urllib.quote(address))
    echo('Checking email address: ' + address)
    result = urllib2.urlopen(request).read()
    checked_addresses[address] = result.find('"_account_id":') >= 0
    if checked_addresses[address]:
      echo('Found email address: ' + address)
  return checked_addresses[address]


def check_address(fname, num, address):
  if find_address(address):
    return 0
  print '%s:%d: ERROR: unknown email address: %s' % (fname, num, address)
  return 1


def main():
  # One regular expression to check all valid lines.
  noparent = 'set +noparent'
  email = '([^@ ]+@[^ @]+|\\*)'
  emails = '(%s( *, *%s)*)' % (email, email)
  file_directive = 'file: *([^ :]+ *: *)?[^ ]+'
  directive = '(%s|%s|%s)' % (emails, noparent, file_directive)
  glob = '[a-zA-Z0-9_\\.\\-\\*\\?]+'
  globs = '(%s( *, *%s)*)' % (glob, glob)
  perfile = 'per-file +' + globs + ' *= *' + directive
  include = 'include +([^ :]+ *: *)?[^ ]+'
  pats = '(|%s|%s|%s|%s|%s)$' % (noparent, email, perfile, include, file_directive)
  patterns = re.compile(pats)
  address_pattern = re.compile('([^@ ]+@[^ @]+)')
  perfile_pattern = re.compile('per-file +.*=(.*)')

  error = 0
  for fname in args.owners:
    echo('Checking file: ' + fname)
    num = 0
    for line in open(fname, 'r'):
      num += 1
      stripped_line = re.sub('#.*$', '', line).strip()
      if not patterns.match(stripped_line):
        error += 1
        print '%s:%d: ERROR: unknown line [%s]' % (fname, num, line.strip())
      elif args.check_address:
        if perfile_pattern.match(stripped_line):
          for addr in perfile_pattern.match(stripped_line).group(1).split(','):
            a = addr.strip()
            if a and a != '*':
              error += check_address(fname, num, addr.strip())
        elif address_pattern.match(stripped_line):
          error += check_address(fname, num, stripped_line)
  sys.exit(error)

if __name__ == '__main__':
  main()
