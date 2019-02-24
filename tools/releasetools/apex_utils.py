#!/usr/bin/env python
#
# Copyright (C) 2019 The Android Open Source Project
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

from __future__ import print_function
import logging
import os.path
import re
import tempfile
import zipfile

import common

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS
BLOCK_SIZE = common.BLOCK_SIZE

class ApexInfoError(Exception):
  """An Exception raised during Apex Information command."""

  def __init__(self, message):
    Exception.__init__(self, message)


class ApexSigningError(Exception):
  """An Exception raised during Apex Payload signing."""

  def __init__(self, message):
    Exception.__init__(self, message)


class ApexPayloadSignerHelper(object):
  """An Apex Payload Signer helper class."""

  def __init__(self, apex_payload_data):
    self.avbtool = 'avbtool'
    self.apex_payload_file = tempfile.NamedTemporaryFile()
    self.apex_payload_file.write(apex_payload_data)
    self.apex_payload_file.flush()
    self.payload_image_info_helper = ApexInfoHelper()
    self.payload_image_info_helper.SetImageInfo(self.avbtool,
                                                self.apex_payload_file.name)

  def GetPayLoadImageInfo(self):
    return self.payload_image_info_helper.GetImageInfo()

  def StripExistingAVBMetaSignature(self, image_path):
    cmd = [self.avbtool, "erase_footer", "--image", image_path]
    proc = common.Run(cmd)
    output, _ = proc.communicate()
    if proc.returncode != 0:
      raise ApexInfoError(
          "Unable to erase VBMeta footer:\n{}".format(output))

  def Verify(self, image_key):
    cmd = [self.avbtool, "verify_image",
           "--image", self.apex_payload_file.name,
           "--key", image_key]
    proc = common.Run(cmd)
    output, _ = proc.communicate()
    if proc.returncode != 0:
      raise ApexSigningError(
          "Unable to validate Image Signing:\n{}".format(output))

  def Sign(self, package_name, image_key, signing_args=None):
    # Strip any existing VBMeta signature/footers.
    try:
      self.StripExistingAVBMetaSignature(self.apex_payload_file.name)
    except ApexInfoError:
      print ("Unable to strip existing VBMeta Signature.")
      raise

    algorithm = self.GetPayLoadImageInfo().get('Algorithm',
                                               OPTIONS.avb_algorithms.get('apex'))
    assert algorithm, 'Missing AVB signing algorithm for %s' % (package_name,)

    salt = self.GetPayLoadImageInfo().get('Salt')

    cmd = [self.avbtool, "add_hashtree_footer",
           "--do_not_generate_fec",
           "--algorithm", algorithm,
           "--key", image_key,
           "--prop", "apex.key:%s" % package_name,
           "--image", self.apex_payload_file.name,
           "--salt", salt]
    if signing_args:
      cmd.extend([signing_args])

    proc = common.Run(cmd)
    output, _ = proc.communicate()
    if proc.returncode != 0:
      raise ApexSigningError(
          "Unable to sign Apex image:\n{}".format(output))

    # Verify the Signed Image with specified public key.
    print ("Verifying %s" % package_name)
    self.Verify(image_key)

    data = None
    with open(self.apex_payload_file.name) as af:
      data = af.read()
    return data


class ApexInfoHelper(object):
  """An Apex Info helper."""

  def __init__(self):
    self.image_info = {}

  def SetImageInfo(self, avbtool, image_path):
    if not os.path.exists(image_path):
      raise ApexInfoError(
          "Unable to find Image: %s" % image_path)

    cmd = [avbtool, "info_image", "--image", image_path]

    # Extract the Algorithm and Salt information from image.
    regex = re.compile('^\s*(?P<key>Algorithm|Salt)\:\s*(?P<value>.*?)$')

    proc = common.Run(cmd)
    for line in iter(proc.stdout.readline, b''):
      _item = regex.match(line)
      if _item:
        item_dict = _item.groupdict()
        self.image_info[item_dict['key']] = item_dict['value']
    output, _ = proc.communicate()
    if proc.returncode != 0:
      raise ApexInfoError(
          "Unable to fetch information:\n{}".format(output))

  def GetImageInfo(self):
    return self.image_info
