#!/usr/bin/env python3
#
# Copyright (C) 2020 The Android Open Source Project
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

import contextlib
import io
import unittest

from unittest.mock import *
from post_process_props import *

class PropTestCase(unittest.TestCase):
  def test_createFromLine(self):
    p = Prop.from_line("# this is comment")
    self.assertTrue(p.is_comment())
    self.assertEqual("", p.name)
    self.assertEqual("", p.value)
    self.assertFalse(p.is_optional())
    self.assertEqual("# this is comment", str(p))

    for line in ["a=b", "a = b", "a= b", "a =b", "  a=b   "]:
      p = Prop.from_line(line)
      self.assertFalse(p.is_comment())
      self.assertEqual("a", p.name)
      self.assertEqual("b", p.value)
      self.assertFalse(p.is_optional())
      self.assertEqual("a=b", str(p))

    for line in ["a?=b", "a ?= b", "a?= b", "a ?=b", "  a?=b   "]:
      p = Prop.from_line(line)
      self.assertFalse(p.is_comment())
      self.assertEqual("a", p.name)
      self.assertEqual("b", p.value)
      self.assertTrue(p.is_optional())
      self.assertEqual("a?=b", str(p))

  def test_makeAsComment(self):
    p = Prop.from_line("a=b")
    p.comments.append("# a comment")
    self.assertFalse(p.is_comment())

    p.make_as_comment()
    self.assertTrue(p.is_comment())
    self.assertEqual("# a comment\n#a=b", str(p))

class PropListTestcase(unittest.TestCase):
  def setUp(self):
    content = """
    # comment
    foo=true
    bar=false
    qux?=1
    # another comment
    foo?=false
    """
    self.patcher = patch("post_process_props.open", mock_open(read_data=content))
    self.mock_open = self.patcher.start()
    self.props = PropList("file")

  def tearDown(self):
    self.patcher.stop()
    self.props = None

  def test_readFromFile(self):
    self.assertEqual(4, len(self.props.get_all_props()))
    expected = [
        ("foo", "true", False),
        ("bar", "false", False),
        ("qux", "1", True),
        ("foo", "false", True)
    ]
    for i,p in enumerate(self.props.get_all_props()):
      self.assertEqual(expected[i][0], p.name)
      self.assertEqual(expected[i][1], p.value)
      self.assertEqual(expected[i][2], p.is_optional())
      self.assertFalse(p.is_comment())

    self.assertEqual(set(["foo", "bar", "qux"]), self.props.get_all_names())

    self.assertEqual("true", self.props.get_value("foo"))
    self.assertEqual("false", self.props.get_value("bar"))
    self.assertEqual("1", self.props.get_value("qux"))

    # there are two assignments for 'foo'
    self.assertEqual(2, len(self.props.get_props("foo")))

  def test_putNewProp(self):
    self.props.put("new", "30")

    self.assertEqual(5, len(self.props.get_all_props()))
    last_prop = self.props.get_all_props()[-1]
    self.assertEqual("new", last_prop.name)
    self.assertEqual("30", last_prop.value)
    self.assertFalse(last_prop.is_optional())

  def test_putExistingNonOptionalProp(self):
    self.props.put("foo", "NewValue")

    self.assertEqual(4, len(self.props.get_all_props()))
    foo_prop = self.props.get_props("foo")[0]
    self.assertEqual("foo", foo_prop.name)
    self.assertEqual("NewValue", foo_prop.value)
    self.assertFalse(foo_prop.is_optional())
    self.assertEqual("# Value overridden by post_process_props.py. " +
                     "Original value: true\nfoo=NewValue", str(foo_prop))

  def test_putExistingOptionalProp(self):
    self.props.put("qux", "2")

    self.assertEqual(5, len(self.props.get_all_props()))
    last_prop = self.props.get_all_props()[-1]
    self.assertEqual("qux", last_prop.name)
    self.assertEqual("2", last_prop.value)
    self.assertFalse(last_prop.is_optional())
    self.assertEqual("# Auto-added by post_process_props.py\nqux=2",
                     str(last_prop))

  def test_deleteNonOptionalProp(self):
    props_to_delete = self.props.get_props("foo")[0]
    props_to_delete.delete(reason="testing")

    self.assertEqual(3, len(self.props.get_all_props()))
    self.assertEqual("# Removed by post_process_props.py because testing\n" +
                     "#foo=true", str(props_to_delete))

  def test_deleteOptionalProp(self):
    props_to_delete = self.props.get_props("qux")[0]
    props_to_delete.delete(reason="testing")

    self.assertEqual(3, len(self.props.get_all_props()))
    self.assertEqual("# Removed by post_process_props.py because testing\n" +
                     "#qux?=1", str(props_to_delete))

  def test_overridingNonOptional(self):
    props_to_be_overridden = self.props.get_props("foo")[1]
    self.assertTrue("true", props_to_be_overridden.value)

    self.assertTrue(override_optional_props(self.props))

    # size reduced to 3 because foo?=false was overridden by foo=true
    self.assertEqual(3, len(self.props.get_all_props()))

    self.assertEqual(1, len(self.props.get_props("foo")))
    self.assertEqual("true", self.props.get_props("foo")[0].value)

    self.assertEqual("# Removed by post_process_props.py because " +
                     "overridden by foo=true\n#foo?=false",
                     str(props_to_be_overridden))

  def test_overridingOptional(self):
    content = """
    # comment
    qux?=2
    foo=true
    bar=false
    qux?=1
    # another comment
    foo?=false
    """
    with patch('post_process_props.open', mock_open(read_data=content)) as m:
      props = PropList("hello")

      props_to_be_overridden = props.get_props("qux")[0]
      self.assertEqual("2", props_to_be_overridden.value)

      self.assertTrue(override_optional_props(props))

      self.assertEqual(1, len(props.get_props("qux")))
      self.assertEqual("1", props.get_props("qux")[0].value)
      # the only left optional assignment becomes non-optional
      self.assertFalse(props.get_props("qux")[0].is_optional())

      self.assertEqual("# Removed by post_process_props.py because " +
                       "overridden by qux?=1\n#qux?=2",
                       str(props_to_be_overridden))

  def test_overridingDuplicated(self):
    content = """
    # comment
    foo=true
    bar=false
    qux?=1
    foo=false
    # another comment
    foo?=false
    """
    with patch("post_process_props.open", mock_open(read_data=content)) as m:
      stderr_redirect = io.StringIO()
      with contextlib.redirect_stderr(stderr_redirect):
        props = PropList("hello")

        # fails due to duplicated foo=true and foo=false
        self.assertFalse(override_optional_props(props))

        self.assertEqual("error: found duplicate sysprop assignments:\n" +
                         "foo=true\nfoo=false\n", stderr_redirect.getvalue())

  def test_overridingDuplicatedWithSameValue(self):
    content = """
    # comment
    foo=true
    bar=false
    qux?=1
    foo=true
    # another comment
    foo?=false
    """
    with patch("post_process_props.open", mock_open(read_data=content)) as m:
      stderr_redirect = io.StringIO()
      with contextlib.redirect_stderr(stderr_redirect):
        props = PropList("hello")
        optional_prop = props.get_props("foo")[2] # the last foo?=false one

        # we have duplicated foo=true and foo=true, but that's allowed
        # since they have the same value
        self.assertTrue(override_optional_props(props))

        # foo?=false should be commented out
        self.assertEqual("# Removed by post_process_props.py because " +
                         "overridden by foo=true\n#foo?=false",
                         str(optional_prop))

  def test_allowDuplicates(self):
    content = """
    # comment
    foo=true
    bar=false
    qux?=1
    foo=false
    # another comment
    foo?=false
    """
    with patch("post_process_props.open", mock_open(read_data=content)) as m:
      stderr_redirect = io.StringIO()
      with contextlib.redirect_stderr(stderr_redirect):
        props = PropList("hello")

        # we have duplicated foo=true and foo=false, but that's allowed
        # because it's explicitly allowed
        self.assertTrue(override_optional_props(props, allow_dup=True))

  def test_validateGrfProps(self):
    stderr_redirect = io.StringIO()
    with contextlib.redirect_stderr(stderr_redirect):
      props = PropList("hello")
      props.put("ro.board.first_api_level","202504")
      props.put("ro.build.version.codename", "REL")

      # manually set ro.board.api_level to an invalid value
      props.put("ro.board.api_level","202404")
      self.assertFalse(validate_grf_props(props))

      props.get_all_props()[-1].make_as_comment()
      # manually set ro.board.api_level to a valid value
      props.put("ro.board.api_level","202504")
      self.assertTrue(validate_grf_props(props))

if __name__ == '__main__':
    unittest.main(verbosity=2)
