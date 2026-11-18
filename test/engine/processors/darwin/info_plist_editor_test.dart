/*
 * Copyright (c) 2026 Angelo Cassano
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

import 'dart:io';

import 'package:flutter_flavorizr/src/engine/processors/darwin/info_plist_editor.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

final String _ios = File(
  'test_resources/darwin/info_plist_test/IosInfoPlistOriginal.plist',
).readAsStringSync();
final String _macos = File(
  'test_resources/darwin/info_plist_test/MacosInfoPlistOriginal.plist',
).readAsStringSync();

const _owned = {
  'CFBundleName': r'$(BUNDLE_NAME)',
  'CFBundleDisplayName': r'$(BUNDLE_DISPLAY_NAME)',
};

/// A plist with the entries [body] in its top level dict.
String _plist(String body) =>
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<plist version="1.0">\n<dict>\n$body</dict>\n</plist>\n';

void main() {
  group('InfoPlistEditor.withStrings', () {
    test('changes only the lines of the owned keys of a pristine plist', () {
      final patched = InfoPlistEditor.withStrings(_ios, {
        ..._owned,
        'UILaunchStoryboardName': r'$(ASSET_PREFIX)LaunchScreen',
      });
      final before = _ios.split('\n');
      final after = patched.split('\n');

      expect(after, hasLength(before.length));

      final changed = [
        for (var i = 0; i < before.length; i++)
          if (before[i] != after[i]) after[i],
      ];

      expect(changed, [
        '\t<string>\$(BUNDLE_DISPLAY_NAME)</string>',
        '\t<string>\$(BUNDLE_NAME)</string>',
        '\t<string>\$(ASSET_PREFIX)LaunchScreen</string>',
      ]);
    });

    test('is the identity once the keys have their values', () {
      final patched = InfoPlistEditor.withStrings(_ios, _owned);

      expect(InfoPlistEditor.withStrings(patched, _owned), patched);
      expect(
        identical(InfoPlistEditor.withStrings(patched, _owned), patched),
        isTrue,
      );
    });

    test('sets the name of a macOS plist and keeps the empty strings', () {
      final patched = InfoPlistEditor.withStrings(_macos, {
        'CFBundleName': r'$(BUNDLE_NAME)',
      });

      expect(
        patched,
        _macos.replaceFirst(r'$(PRODUCT_NAME)', r'$(BUNDLE_NAME)'),
      );
      expect(patched, contains('<string></string>'));
    });

    test('keeps every other byte of a hand written plist', () {
      // Spaces and tabs, CRLF, comments that look like entries, a key repeated
      // in a nested dict, an array, and the keys in an odd order.
      const source =
          '<?xml version="1.0" encoding="UTF-8"?>\r\n'
          '<!-- <key>CFBundleName</key><string>comment</string> -->\r\n'
          '<plist version="1.0">\r\n'
          '  <dict>\r\n'
          '\t<key>Nested</key>\r\n'
          '\t<dict><key>CFBundleName</key><string>nested</string></dict>\r\n'
          '    <key>CFBundleDisplayName</key>\r\n'
          '    <string>  Display  </string>\r\n'
          '\t<key>List</key><array><string>CFBundleName</string></array>\r\n'
          '    <!-- note -->\r\n'
          '    <key>CFBundleName</key>   <string>example</string>\r\n'
          '  </dict>\r\n'
          '</plist>';

      expect(
        InfoPlistEditor.withStrings(source, _owned),
        source
            .replaceFirst('  Display  ', r'$(BUNDLE_DISPLAY_NAME)')
            .replaceFirst(
              '<key>CFBundleName</key>   <string>example',
              r'<key>CFBundleName</key>   <string>$(BUNDLE_NAME)',
            ),
      );
    });

    test('edits a self closing, an empty and an escaped string', () {
      final patched = InfoPlistEditor.withStrings(
        _plist(
          '<key>CFBundleName</key><string/>\n'
          '<key>CFBundleDisplayName</key><string>a &amp; b</string>\n',
        ),
        _owned,
      );

      expect(
        patched,
        _plist(
          '<key>CFBundleName</key><string>\$(BUNDLE_NAME)</string>\n'
          '<key>CFBundleDisplayName</key><string>\$(BUNDLE_DISPLAY_NAME)</string>\n',
        ),
      );
    });

    test('fills an empty string', () {
      expect(
        InfoPlistEditor.withStrings(
          _plist('<key>CFBundleName</key>\n<string></string>\n'),
          {'CFBundleName': 'x'},
        ),
        _plist('<key>CFBundleName</key>\n<string>x</string>\n'),
      );
    });

    test('reads a value written with entities or a CDATA section', () {
      final source = _plist(
        '<key>CFBundleName</key><string>\$(BUNDLE&#95;NAME)</string>\n'
        '<key>CFBundleDisplayName</key>'
        '<string><![CDATA[\$(BUNDLE_DISPLAY_NAME)]]></string>\n',
      );

      expect(InfoPlistEditor.withStrings(source, _owned), source);
    });

    test('edits the first of a key that is repeated', () {
      final patched = InfoPlistEditor.withStrings(
        _plist(
          '<key>CFBundleName</key><string>one</string>\n'
          '<key>CFBundleName</key><string>two</string>\n',
        ),
        {'CFBundleName': 'x'},
      );

      expect(patched, contains('<string>x</string>'));
      expect(patched, contains('<string>two</string>'));
    });

    test('does not mistake a value for a key', () {
      final source = _plist(
        '<key>Other</key><string>CFBundleName</string>\n'
        '<key>CFBundleName</key><string>example</string>\n',
      );

      expect(
        InfoPlistEditor.withStrings(source, {'CFBundleName': 'x'}),
        source.replaceFirst('example', 'x'),
      );
    });

    test('refuses a plist without the key, with a value that is not a string '
        'or that is not plain text', () {
      for (final source in [
        _plist('<key>Other</key><string>x</string>\n'),
        _plist('<key>CFBundleName</key><true/>\n'),
        _plist('<key>CFBundleName</key><array><string>x</string></array>\n'),
        _plist('<key>CFBundleName</key><string>a<!-- c -->b</string>\n'),
        _plist('<key>CFBundleName</key><string>a<b/>c</string>\n'),
        '<plist version="1.0"><array/></plist>',
        '<plist version="1.0"/>',
      ]) {
        expect(
          () => InfoPlistEditor.withStrings(source, {'CFBundleName': 'x'}),
          throwsA(isA<MalformedResourceException>()),
          reason: source,
        );
      }
    });

    test('refuses a document that is not well formed', () {
      expect(
        () => InfoPlistEditor.withStrings('<plist><dict>', _owned),
        throwsA(isA<XmlException>()),
      );
    });
  });

  group('InfoPlistEditor.ownedContent', () {
    test('is the name and the display name of an iOS plist', () {
      expect(
        InfoPlistEditor.iosOwnedContent(_ios),
        'CFBundleName=example\nCFBundleDisplayName=Example',
      );
    });

    test('has the launch storyboard only when flavorizr set it', () {
      final patched = InfoPlistEditor.withStrings(_ios, {
        'UILaunchStoryboardName': r'$(ASSET_PREFIX)LaunchScreen',
      });

      expect(
        InfoPlistEditor.iosOwnedContent(patched),
        contains(r'UILaunchStoryboardName=$(ASSET_PREFIX)LaunchScreen'),
      );
      expect(
        InfoPlistEditor.iosOwnedContent(_ios),
        isNot(contains('UILaunchStoryboardName')),
      );
    });

    test('does not change with the rest of the plist', () {
      final edited = _ios
          .replaceFirst('Main', 'Other')
          .replaceFirst('<false/>', '<true/>')
          .replaceAll('\t', '    ');

      expect(
        InfoPlistEditor.iosOwnedContent(edited),
        InfoPlistEditor.iosOwnedContent(_ios),
      );
    });

    test('changes with an edit of an owned key', () {
      expect(
        InfoPlistEditor.iosOwnedContent(_ios.replaceFirst('example', 'mine')),
        isNot(InfoPlistEditor.iosOwnedContent(_ios)),
      );
    });

    test('is the name of a macOS plist', () {
      expect(
        InfoPlistEditor.macosOwnedContent(_macos),
        r'CFBundleName=$(PRODUCT_NAME)',
      );
    });
  });
}
