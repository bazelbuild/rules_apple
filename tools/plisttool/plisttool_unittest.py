# coding=utf-8
# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Tests for PlistTool."""

from collections import OrderedDict
import plistlib
import random
import re
import StringIO
import unittest

import plisttool

# Used as the target name for all tests.
_testing_target = '//plisttool:tests'


def _xml_plist(content):
  """Returns a StringIO for a plist with the given content.

  This helper function wraps plist XML (key/value pairs) in the necessary XML
  boilerplate for a plist with a root dictionary.

  Args:
    content: The XML content of the plist, which will be inserted into a
        dictionary underneath the root |plist| element.
  Returns:
    A StringIO object containing the full XML text of the plist.
  """
  xml = ('<?xml version="1.0" encoding="UTF-8"?>\n'
         '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
         '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
         '<plist version="1.0">\n'
         '<dict>\n' +
         content + '\n' +
         '</dict>\n'
         '</plist>\n')
  return StringIO.StringIO(xml)


def _plisttool_result(control):
  """Helper function that runs PlistTool with the given control struct.

  This function inserts a StringIO object as the control's "output" key and
  returns the dictionary containing the result of the tool after parsing it
  from that StringIO.

  Args:
    control: The control struct to pass to PlistTool. See the module doc for
        the plisttool module for a description of this format.
  Returns:
    The dictionary containing the result of the tool after parsing it from
    the in-memory string file.
  """
  output = StringIO.StringIO()
  control['output'] = output
  control['target'] = _testing_target

  tool = plisttool.PlistTool(control)
  tool.run()

  return plistlib.readPlistFromString(output.getvalue())


class PlistToolVariableReferenceTest(unittest.TestCase):

  def _assert_result(self, s, expected):
    """Asserts string is the expected variable reference."""
    m = plisttool.VARIABLE_REFERENCE_RE.match(s)
    # Testing that based on the whole string.
    self.assertEqual(m.group(0), s)
    self.assertEqual(plisttool.ExtractVariableFromMatch(m), expected)

  def _assert_invalid(self, s):
    """Asserts string is not a valid variable reference."""
    self._assert_result(s, None)

  def test_valid_parens(self):
    self._assert_result('$(foo)', 'foo')
    self._assert_result('$(FOO12)', 'FOO12')
    self._assert_result('$(PRODUCT_NAME:rfc1034identifier)',
                        'PRODUCT_NAME:rfc1034identifier')

  def test_valid_braces(self):
    self._assert_result('${foo}', 'foo')
    self._assert_result('${FOO12}', 'FOO12')
    self._assert_result('${PRODUCT_NAME:rfc1034identifier}',
                        'PRODUCT_NAME:rfc1034identifier')

  def test_empty_reference(self):
    self._assert_invalid('$()')
    self._assert_invalid('${}')

  def test_mismatched_bracing(self):
    self._assert_invalid('${foo)')
    self._assert_invalid('$(foo}')

  def test_invalid_names(self):
    self._assert_invalid('${no space}')
    self._assert_invalid('${no-hypens}')

  def test_unknown_qualifier(self):
    self._assert_invalid('${foo:mumble}')
    self._assert_invalid('${foo:rfc666dentifier}')

  def test_missing_closer(self):
    # Valid, just missing the closer...
    self._assert_invalid('$(foo')
    self._assert_invalid('$(FOO12')
    self._assert_invalid('$(PRODUCT_NAME:rfc1034identifier')
    self._assert_invalid('${foo')
    self._assert_invalid('${FOO12')
    self._assert_invalid('${PRODUCT_NAME:rfc1034identifier')
    # Invalid and missing the closer...
    self._assert_invalid('${no space')
    self._assert_invalid('${no-hypens')
    self._assert_invalid('${foo:mumble')
    self._assert_invalid('${foo:rfc666dentifier')


class PlistToolTest(unittest.TestCase):

  def _assert_plisttool_result(self, control, expected):
    """Asserts that PlistTool's result equals the expected dictionary.

    Args:
      control: The control struct to pass to PlistTool. See the module doc for
          the plisttool module for a description of this format.
      expected: The dictionary that represents the expected result from running
          PlistTool.
    """
    outdict = _plisttool_result(control)
    self.assertEqual(expected, outdict)

  def _assert_pkginfo(self, plist, expected):
    """Asserts that PlistTool generates the expected PkgInfo file contents.

    Args:
      plist: The plist file from which to obtain the PkgInfo values.
      expected: The expected 8-byte string written to the PkgInfo file.
    """
    pkginfo = StringIO.StringIO()
    control = {
        'plists': [plist],
        'output': StringIO.StringIO(),
        'target': _testing_target,
        'info_plist_options': {'pkginfo': pkginfo},
    }
    tool = plisttool.PlistTool(control)
    tool.run()
    self.assertEqual(expected, pkginfo.getvalue())

  def test_merge_of_one_file(self):
    plist1 = _xml_plist('<key>Foo</key><string>abc</string>')
    self._assert_plisttool_result({'plists': [plist1]}, {'Foo': 'abc'})

  def test_merge_of_one_dict(self):
    plist1 = {'Foo': 'abc'}
    self._assert_plisttool_result({'plists': [plist1]}, {'Foo': 'abc'})

  def test_merge_of_one_empty_file(self):
    plist1 = _xml_plist('')
    self._assert_plisttool_result({'plists': [plist1]}, {})

  def test_merge_of_one_empty_dict(self):
    plist1 = {}
    self._assert_plisttool_result({'plists': [plist1]}, {})

  def test_merge_of_two_files(self):
    plist1 = _xml_plist('<key>Foo</key><string>abc</string>')
    plist2 = _xml_plist('<key>Bar</key><string>def</string>')
    self._assert_plisttool_result({'plists': [plist1, plist2]}, {
        'Foo': 'abc',
        'Bar': 'def',
    })

  def test_merge_of_file_and_dict(self):
    plist1 = _xml_plist('<key>Foo</key><string>abc</string>')
    plist2 = {'Bar': 'def'}
    self._assert_plisttool_result({'plists': [plist1, plist2]}, {
        'Foo': 'abc',
        'Bar': 'def',
    })

  def test_merge_of_two_dicts(self):
    plist1 = {'Foo': 'abc'}
    plist2 = {'Bar': 'def'}
    self._assert_plisttool_result({'plists': [plist1, plist2]}, {
        'Foo': 'abc',
        'Bar': 'def',
    })

  def test_merge_where_one_file_is_empty(self):
    plist1 = _xml_plist('<key>Foo</key><string>abc</string>')
    plist2 = _xml_plist('')
    self._assert_plisttool_result({'plists': [plist1, plist2]}, {'Foo': 'abc'})

  def test_merge_where_one_dict_is_empty(self):
    plist1 = {'Foo': 'abc'}
    plist2 = {}
    self._assert_plisttool_result({'plists': [plist1, plist2]}, {'Foo': 'abc'})

  def test_merge_where_both_files_are_empty(self):
    plist1 = _xml_plist('')
    plist2 = _xml_plist('')
    self._assert_plisttool_result({'plists': [plist1, plist2]}, {})

  def test_merge_where_both_dicts_are_empty(self):
    plist1 = {}
    plist2 = {}
    self._assert_plisttool_result({'plists': [plist1, plist2]}, {})

  def test_more_complicated_merge(self):
    plist1 = _xml_plist(
        '<key>String1</key><string>abc</string>'
        '<key>Integer1</key><integer>123</integer>'
        '<key>Array1</key><array><string>a</string><string>b</string></array>'
    )
    plist2 = _xml_plist(
        '<key>String2</key><string>def</string>'
        '<key>Integer2</key><integer>987</integer>'
        '<key>Dictionary2</key><dict>'
        '<key>k1</key><string>a</string>'
        '<key>k2</key><string>b</string>'
        '</dict>'
    )
    plist3 = _xml_plist(
        '<key>String3</key><string>ghi</string>'
        '<key>Integer3</key><integer>465</integer>'
        '<key>Bundle</key><string>this.is.${BUNDLE_NAME}.bundle</string>'
    )
    self._assert_plisttool_result({
        'plists': [plist1, plist2, plist3],
        'substitutions': {
            'BUNDLE_NAME': 'my'
        },
    }, {
        'String1': 'abc',
        'Integer1': 123,
        'Array1': ['a', 'b'],
        'String2': 'def',
        'Integer2': 987,
        'Dictionary2': {'k1': 'a', 'k2': 'b'},
        'String3': 'ghi',
        'Integer3': 465,
        'Bundle': 'this.is.my.bundle',
    })

  def test_merge_with_forced_plist_overrides_on_collisions(self):
    plist1 = {'Foo': 'bar'}
    plist2 = {'Foo': 'baz'}
    self._assert_plisttool_result({
        'plists': [plist1],
        'forced_plists': [plist2],
    }, {'Foo': 'baz'})

  def test_merge_with_forced_plists_with_same_key_keeps_last_one(self):
    plist1 = {'Foo': 'bar'}
    plist2 = {'Foo': 'baz'}
    plist3 = {'Foo': 'quux'}
    self._assert_plisttool_result({
        'plists': [plist1],
        'forced_plists': [plist2, plist3],
    }, {'Foo': 'quux'})

  def test_invalid_substitution_name_space(self):
    with self.assertRaisesRegexp(
        ValueError,
        re.escape(plisttool.INVALID_SUBSTITUTION_VARIABLE_NAME % (
            _testing_target, 'foo bar'))):
      _plisttool_result({
         'plists': [{}],
         'substitutions': {
              'foo bar': 'bad name',
          },
      })

  def test_invalid_substitution_name_hyphen(self):
    with self.assertRaisesRegexp(
        ValueError,
        re.escape(plisttool.INVALID_SUBSTITUTION_VARIABLE_NAME % (
            _testing_target, 'foo-bar'))):
      _plisttool_result({
         'plists': [{}],
         'substitutions': {
              'foo-bar': 'bad name',
          },
      })

  def test_invalid_substitution_name_qualifier(self):
    with self.assertRaisesRegexp(
        ValueError,
        re.escape(plisttool.INVALID_SUBSTITUTION_VARIABLE_NAME % (
            _testing_target, 'foo:bar'))):
      _plisttool_result({
         'plists': [{}],
         'substitutions': {
              'foo:bar': 'bad name',
          },
      })

  def test_invalid_substitution_name_rfc_qualifier(self):
    with self.assertRaisesRegexp(
        ValueError,
        re.escape(plisttool.SUBSTITUTION_VARIABLE_CANT_HAVE_QUALIFIER % (
            _testing_target, 'foo:rfc1034identifier'))):
      _plisttool_result({
         'plists': [{}],
         'substitutions': {
              'foo:rfc1034identifier': 'bad name',
          },
      })

  def test_invalid_info_plist_options_value(self):
    with self.assertRaisesRegexp(
        ValueError,
        re.escape(plisttool.INFO_PLIST_OPTION_VALUE_HAS_VARIABLE_MSG % (
            _testing_target, 'mumble', 'foo.bar.${NotSupported}'))):
      _plisttool_result({
         'plists': [{}],
         'substitutions': {
              'mumble': 'foo.bar.${NotSupported}',
          },
      })

  def test_product_name_substitutions(self):
    plist1 = _xml_plist(
        '<key>FooBraces</key><string>${TARGET_NAME}</string>'
        '<key>BarBraces</key><string>${PRODUCT_NAME}</string>'
        '<key>FooParens</key><string>$(TARGET_NAME)</string>'
        '<key>BarParens</key><string>$(PRODUCT_NAME)</string>'
    )
    outdict = _plisttool_result({
        'plists': [plist1],
        'substitutions': {
            'PRODUCT_NAME': 'MyApp',
            'TARGET_NAME': 'MyApp',
        },
    })
    self.assertEqual('MyApp', outdict.get('FooBraces'))
    self.assertEqual('MyApp', outdict.get('BarBraces'))
    self.assertEqual('MyApp', outdict.get('FooParens'))
    self.assertEqual('MyApp', outdict.get('BarParens'))

  def test_rfc1034_conversion(self):
    plist1 = _xml_plist(
        '<key>Foo</key><string>${PRODUCT_NAME:rfc1034identifier}</string>'
    )
    outdict = _plisttool_result({
        'plists': [plist1],
        'substitutions': {
            'PRODUCT_NAME': 'foo_bar?baz'
        },
    })
    self.assertEqual('foo-bar-baz', outdict.get('Foo'))

  def test_nonexistant_substitution(self):
    plist1 = {
        'FooBraces': 'A-${NOT_A_VARIABLE}-B'
    }
    with self.assertRaisesRegexp(
        ValueError,
        re.escape(plisttool.UNKNOWN_SUBSTITUTATION_REFERENCE_MSG % (
            _testing_target, '${NOT_A_VARIABLE}', 'FooBraces',
            'A-${NOT_A_VARIABLE}-B'))):
      _plisttool_result({'plists': [plist1]})

    plist2 = {
        'FooParens': '$(NOT_A_VARIABLE)'
    }
    with self.assertRaisesRegexp(
        ValueError,
        re.escape(plisttool.UNKNOWN_SUBSTITUTATION_REFERENCE_MSG % (
            _testing_target, '$(NOT_A_VARIABLE)', 'FooParens',
            '$(NOT_A_VARIABLE)'))):
      _plisttool_result({'plists': [plist2]})

    # Nested dict, will include the keypath.
    plist3 = {
        'Key1': {
            'Key2': 'foo.bar.$(PRODUCT_NAME:rfc1034identifier)'
        }
    }
    with self.assertRaisesRegexp(
        ValueError,
        re.escape(plisttool.UNKNOWN_SUBSTITUTATION_REFERENCE_MSG % (
            _testing_target, '$(PRODUCT_NAME:rfc1034identifier)',
            'Key1:Key2', 'foo.bar.$(PRODUCT_NAME:rfc1034identifier)'))):
      _plisttool_result({'plists': [plist3]})

    # Array, will include the keypath.
    plist3 = {
        'Key': [
            'this one is ok',
            'foo.bar.$(PRODUCT_NAME:rfc1034identifier)'
        ]
    }
    with self.assertRaisesRegexp(
        ValueError,
        re.escape(plisttool.UNKNOWN_SUBSTITUTATION_REFERENCE_MSG % (
            _testing_target, '$(PRODUCT_NAME:rfc1034identifier)',
            'Key[1]', 'foo.bar.$(PRODUCT_NAME:rfc1034identifier)'))):
      _plisttool_result({'plists': [plist3]})

  def test_invalid_substitution(self):
    plist1 = {
        'Foo': 'foo.${INVALID_REFERENCE).bar'
    }
    with self.assertRaisesRegexp(
        ValueError,
        re.escape(plisttool.INVALID_SUBSTITUTATION_REFERENCE_MSG % (
            _testing_target, '${INVALID_REFERENCE)', 'Foo',
            'foo.${INVALID_REFERENCE).bar'))):
      _plisttool_result({'plists': [plist1]})

  def test_multiple_substitutions(self):
    plist1 = _xml_plist(
        '<key>Foo</key>'
        '<string>${PRODUCT_NAME}--${BUNDLE_NAME}--${EXECUTABLE_NAME}</string>'
    )
    outdict = _plisttool_result({
        'plists': [plist1],
        'substitutions': {
            'EXECUTABLE_NAME': 'MyExe',
            'BUNDLE_NAME': 'MyBundle',
            'PRODUCT_NAME': 'MyApp',
        },
    })
    self.assertEqual('MyApp--MyBundle--MyExe', outdict.get('Foo'))

  def test_recursive_substitutions(self):
    plist1 = _xml_plist(
        '<key>Foo</key>'
        '<dict>'
        '  <key>Foo1</key>'
        '  <string>${BUNDLE_NAME}</string>'
        '  <key>Foo2</key>'
        '  <array>'
        '    <string>${BUNDLE_NAME}</string>'
        '  </array>'
        '</dict>'
        '<key>Bar</key>'
        '<array>'
        '  <string>${BUNDLE_NAME}</string>'
        '  <dict>'
        '    <key>Baz</key>'
        '    <string>${BUNDLE_NAME}</string>'
        '  </dict>'
        '</array>'
    )
    outdict = _plisttool_result({
        'plists': [plist1],
        'substitutions': {
            'BUNDLE_NAME': 'MyBundle',
        },
    })
    self.assertEqual('MyBundle', outdict.get('Foo').get('Foo1'))
    self.assertEqual('MyBundle', outdict.get('Foo').get('Foo2')[0])
    self.assertEqual('MyBundle', outdict.get('Bar')[0])
    self.assertEqual('MyBundle', outdict.get('Bar')[1].get('Baz'))

  def test_keys_with_same_values_do_not_raise_error(self):
    plist1 = _xml_plist('<key>Foo</key><string>Bar</string>')
    plist2 = _xml_plist('<key>Foo</key><string>Bar</string>')
    self._assert_plisttool_result({'plists': [plist1, plist2]}, {'Foo': 'Bar'})

  def test_conflicting_keys_raises_error(self):
    with self.assertRaises(plisttool.PlistConflictError) as context:
      plist1 = _xml_plist('<key>Foo</key><string>Bar</string>')
      plist2 = _xml_plist('<key>Foo</key><string>Baz</string>')
      _plisttool_result({'plists': [plist1, plist2]})

    self.assertEqual(_testing_target, context.exception.target_label)
    self.assertEqual('Foo', context.exception.key)
    # Don't care about the order of the values.
    values = set([context.exception.value1, context.exception.value2])
    self.assertIn('Bar', values)
    self.assertIn('Baz', values)

  def test_order_of_elements_in_one_plist_merge_is_maintained(self):
    """Verify that we merge keys in the same order as the original dictionary.

    Ordering of keys is important in build caching -- the ordering must be
    deterministic. Xcode, which is built on Foundation's non-order-preserving
    NSDictionary, is harmful to caching because it merges keys in arbitrary
    order.

    We do our merging in insertion order, which is deterministic. The plistlib
    module reads plists into a standard Python dictionary, which is hashed, and
    then we immediately copy the entries into an OrderedDict. The original
    arbitrary ordering initially seems problematic, but we can assume that two
    dictionaries that are built by inserting the same keys in the same order,
    without any intervening removals, will produce the same hashtable structure
    and would be iterated in the same order (this matters when building the
    OrderedDict). From that point on, we operate only on OrderedDicts, which
    preserves the order, and finally, writePlist iterates over the OrderedDict
    and writes the XML plist back out in that order.
    """
    # NOTE: With this seed, one key is generated twice so the dictionary only
    # ends up with 49999 items.
    random.seed(8675309)
    key_order = OrderedDict()
    source_plist = OrderedDict()
    for _ in range(50000):
      key = 'key#%d' % random.randint(0, 2 ** 32 - 1)
      key_order[key] = True
      source_plist[key] = 'value'

    outdict = OrderedDict()
    tool = plisttool.PlistTool({})
    tool.merge_dictionaries(source_plist, outdict, _testing_target)

    self.assertEqual(outdict.keys(), key_order.keys())

  def test_pkginfo_with_valid_values(self):
    self._assert_pkginfo({
        'CFBundlePackageType': 'APPL',
        'CFBundleSignature': '1234',
    }, 'APPL1234')

  def test_pkginfo_with_missing_package_type(self):
    self._assert_pkginfo({
        'CFBundleSignature': '1234',
    }, '????1234')

  def test_pkginfo_with_missing_signature(self):
    self._assert_pkginfo({
        'CFBundlePackageType': 'APPL',
    }, 'APPL????')

  def test_pkginfo_with_missing_package_type_and_signature(self):
    self._assert_pkginfo({}, '????????')

  def test_pkginfo_with_values_too_long(self):
    self._assert_pkginfo({
        'CFBundlePackageType': 'APPLE',
        'CFBundleSignature': '1234',
    }, '????1234')

  def test_pkginfo_with_valid_values_too_short(self):
    self._assert_pkginfo({
        'CFBundlePackageType': 'APPL',
        'CFBundleSignature': '123',
    }, 'APPL????')

  def test_pkginfo_with_values_encodable_in_mac_roman(self):
    self._assert_pkginfo({
        'CFBundlePackageType': u'ÄPPL',
        'CFBundleSignature': '1234',
    }, '\x80PPL1234')

  def test_pkginfo_with_values_not_encodable_in_mac_roman(self):
    self._assert_pkginfo({
        'CFBundlePackageType': u'😎',
        'CFBundleSignature': '1234',
    }, '????1234')

  def test_child_plist_that_matches_parent_does_not_raise(self):
    parent = _xml_plist(
        '<key>CFBundleIdentifier</key><string>foo.bar</string>'
        '<key>CFBundleShortVersionString</key><string>1.2.3</string>')
    child = _xml_plist(
        '<key>CFBundleIdentifier</key><string>foo.bar.baz</string>'
        '<key>CFBundleShortVersionString</key><string>1.2.3</string>')
    children = {'//fake:label': child}
    _plisttool_result({
        'plists': [parent],
        'info_plist_options': {
            'child_plists': children,
        },
    })

  def test_child_plist_with_incorrect_bundle_id_raises(self):
    with self.assertRaisesRegexp(
        ValueError,
        re.escape(plisttool.CHILD_BUNDLE_ID_MISMATCH_MSG % (
            _testing_target, '//fake:label', 'foo.bar.', 'foo.baz'))):
      parent = _xml_plist(
          '<key>CFBundleIdentifier</key><string>foo.bar</string>'
          '<key>CFBundleShortVersionString</key><string>1.2.3</string>')
      child = _xml_plist(
          '<key>CFBundleIdentifier</key><string>foo.baz</string>'
          '<key>CFBundleShortVersionString</key><string>1.2.3</string>')
      children = {'//fake:label': child}
      _plisttool_result({
          'plists': [parent],
          'info_plist_options': {
              'child_plists': children,
          },
      })

  def test_child_plist_with_incorrect_bundle_version_raises(self):
    with self.assertRaisesRegexp(
        ValueError,
        re.escape(plisttool.CHILD_BUNDLE_VERSION_MISMATCH_MSG % (
            _testing_target, '//fake:label', '1.2.3', '1.2.4'))):
      parent = _xml_plist(
          '<key>CFBundleIdentifier</key><string>foo.bar</string>'
          '<key>CFBundleShortVersionString</key><string>1.2.3</string>')
      child = _xml_plist(
          '<key>CFBundleIdentifier</key><string>foo.bar.baz</string>'
          '<key>CFBundleShortVersionString</key><string>1.2.4</string>')
      children = {'//fake:label': child}
      _plisttool_result({
          'plists': [parent],
          'info_plist_options': {
              'child_plists': children,
          },
      })

  def test_unknown_control_keys_raise(self):
    with self.assertRaisesRegexp(
        ValueError,
        re.escape(plisttool.UNKNOWN_CONTROL_KEYS_MSG % (
            _testing_target, 'unknown'))):
      plist = {'Foo': 'bar'}
      _plisttool_result({
          'plists': [plist],
          'unknown': True,
      })

  def test_unknown_control_keys_raise(self):
    with self.assertRaisesRegexp(
        ValueError,
        re.escape(plisttool.UNKNOWN_INFO_PLIST_OPTIONS_MSG % (
            _testing_target, 'mumble'))):
      plist = {'Foo': 'bar'}
      children = {'//fake:label': {'foo': 'bar'}}
      _plisttool_result({
          'plists': [plist],
          'info_plist_options': {
              'child_plists': children,
              'mumble': 'something',
          },
      })


if __name__ == '__main__':
  unittest.main()
