#!/usr/bin/env python
#
# Copyright (C) 2016 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Verify a given OTA package with the specifed certificate.
"""

from __future__ import print_function

import argparse
import common
import re
import subprocess
import sys

from hashlib import sha1
from hashlib import sha256


def cert_uses_sha256(cert):
  """Check if the cert uses SHA-256 hashing algorithm."""

  cmd = ['openssl', 'x509', '-text', '-noout', '-in', cert]
  p1 = common.Run(cmd, stdout=subprocess.PIPE)
  cert_dump, _ = p1.communicate()

  algorithm = re.search(r'Signature Algorithm: ([a-zA-Z0-9]+)', cert_dump)
  assert algorithm, "Failed to identify the signature algorithm."

  assert not algorithm.group(1).startswith('ecdsa'), (
      'This script doesn\'t support verifying ECDSA signed package yet.')

  return algorithm.group(1).startswith('sha256')


def verify_package(cert, package):
  """Verify the given package with the certificate.

  (Comments from bootable/recovery/verifier.cpp:)

  An archive with a whole-file signature will end in six bytes:

    (2-byte signature start) $ff $ff (2-byte comment size)

  (As far as the ZIP format is concerned, these are part of the
  archive comment.) We start by reading this footer, this tells
  us how far back from the end we have to start reading to find
  the whole comment.
  """

  print('Package: %s' % (package,))
  print('Certificate: %s' % (cert,))

  # Read in the package.
  with open(package) as package_file:
    package_bytes = package_file.read()

  length = len(package_bytes)
  assert length >= 6, "Not big enough to contain footer."

  footer = [ord(x) for x in package_bytes[-6:]]
  assert footer[2] == 0xff and footer[3] == 0xff, "Footer is wrong."

  signature_start_from_end = (footer[1] << 8) + footer[0]
  assert signature_start_from_end > 6, "Signature start is in the footer."

  signature_start = length - signature_start_from_end

  # Determine how much of the file is covered by the signature. This is
  # everything except the signature data and length, which includes all of the
  # EOCD except for the comment length field (2 bytes) and the comment data.
  comment_len = (footer[5] << 8) + footer[4]
  signed_len = length - comment_len - 2

  print('Package length: %d' % (length,))
  print('Comment length: %d' % (comment_len,))
  print('Signed data length: %d' % (signed_len,))
  print('Signature start: %d' % (signature_start,))

  use_sha256 = cert_uses_sha256(cert)
  print('Use SHA-256: %s' % (use_sha256,))

  if use_sha256:
    h = sha256()
  else:
    h = sha1()
  h.update(package_bytes[:signed_len])
  package_digest = h.hexdigest().lower()

  print('Digest: %s\n' % (package_digest,))

  # Get the signature from the input package.
  signature = package_bytes[signature_start:-6]
  sig_file = common.MakeTempFile(prefix='sig-')
  with open(sig_file, 'wb') as f:
    f.write(signature)

  # Parse the signature and get the hash.
  cmd = ['openssl', 'asn1parse', '-inform', 'DER', '-in', sig_file]
  p1 = common.Run(cmd, stdout=subprocess.PIPE)
  sig, _ = p1.communicate()
  assert p1.returncode == 0, "Failed to parse the signature."

  digest_line = sig.strip().split('\n')[-1]
  digest_string = digest_line.split(':')[3]
  digest_file = common.MakeTempFile(prefix='digest-')
  with open(digest_file, 'wb') as f:
    f.write(digest_string.decode('hex'))

  # Verify the digest by outputing the decrypted result in ASN.1 structure.
  decrypted_file = common.MakeTempFile(prefix='decrypted-')
  cmd = ['openssl', 'rsautl', '-verify', '-certin', '-inkey', cert,
         '-in', digest_file, '-out', decrypted_file]
  p1 = common.Run(cmd, stdout=subprocess.PIPE)
  p1.communicate()
  assert p1.returncode == 0, "Failed to run openssl rsautl -verify."

  # Parse the output ASN.1 structure.
  cmd = ['openssl', 'asn1parse', '-inform', 'DER', '-in', decrypted_file]
  p1 = common.Run(cmd, stdout=subprocess.PIPE)
  decrypted_output, _ = p1.communicate()
  assert p1.returncode == 0, "Failed to parse the output."

  digest_line = decrypted_output.strip().split('\n')[-1]
  digest_string = digest_line.split(':')[3].lower()

  # Verify that the two digest strings match.
  assert package_digest == digest_string, "Verification failed."

  # Verified successfully upon reaching here.
  print('VERIFIED\n')


def main():
  parser = argparse.ArgumentParser()
  parser.add_argument('certificate', help='The certificate to be used.')
  parser.add_argument('package', help='The OTA package to be verified.')
  args = parser.parse_args()

  verify_package(args.certificate, args.package)


if __name__ == '__main__':
  try:
    main()
  except AssertionError as err:
    print('\n    ERROR: %s\n' % (err,))
    sys.exit(1)
