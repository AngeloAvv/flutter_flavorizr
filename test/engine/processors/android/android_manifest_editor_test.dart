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

import 'package:flutter_flavorizr/src/engine/processors/android/android_manifest_editor.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('AndroidManifestEditor.withAppLabel', () {
    test('points the label of the application to the app name', () {
      const source =
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '  <application android:label="example"/>\n'
          '</manifest>\n';

      expect(
        AndroidManifestEditor.withAppLabel(source),
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '  <application android:label="@string/app_name"/>\n'
        '</manifest>\n',
      );
    });

    test('is the identity when the label already points to the app name', () {
      const source =
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '  <application android:label="@string/app_name"/>\n'
          '</manifest>\n';

      expect(AndroidManifestEditor.withAppLabel(source), source);
    });

    test('keeps every other byte of a hand written manifest', () {
      // Tabs, CRLF, an odd attribute order, single quotes, spaces around `=`,
      // a `>` inside an attribute value and comments that look like tags.
      const source =
          '<?xml version="1.0" encoding="utf-8"?>\r\n'
          '<!-- <application android:label="from a comment"> -->\r\n'
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android"\r\n'
          '\t\txmlns:tools="http://schemas.android.com/tools"   package="com.example">\r\n'
          '\t<application\r\n'
          "\t\tandroid:name='com.example.App&gt;'\r\n"
          '\t\tandroid:description="a > b / c"\r\n'
          '\t\ttools:replace = "android:label"\r\n'
          "\t\tandroid:label  =  'example'\r\n"
          '\t\tandroid:icon="@mipmap/ic_launcher">\r\n'
          '\t\t<!-- <application android:label="nested"> -->\r\n'
          '\t\t<meta-data android:name="a" android:value="b" />\r\n'
          '\t</application>\r\n'
          '</manifest>';

      expect(
        AndroidManifestEditor.withAppLabel(source),
        source.replaceFirst("'example'", "'@string/app_name'"),
      );
    });

    test('edits the first application only', () {
      const source =
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
          '<application android:label="one"/>'
          '<application android:label="two"/>'
          '</manifest>';

      expect(
        AndroidManifestEditor.withAppLabel(source),
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
        '<application android:label="@string/app_name"/>'
        '<application android:label="two"/>'
        '</manifest>',
      );
    });

    test('does not match a label of another namespace or element', () {
      const source =
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
          '<application other:label="x" android:labelling="y" '
          'android:label="z">'
          '<activity android:label="activity"/>'
          '</application>'
          '</manifest>';

      expect(
        AndroidManifestEditor.withAppLabel(source),
        source.replaceFirst('"z"', '"@string/app_name"'),
      );
    });

    test('reads tags separated by any white space the XML parser accepts', () {
      for (final space in ['\u00a0', '\u000b', '\u000c', '\u2003', '\u0085']) {
        final source =
            '<manifest xmlns:android="x"><application${space}android:label$space=$space"a"$space/></manifest>';

        expect(
          AndroidManifestEditor.withAppLabel(source),
          source.replaceFirst('"a"', '"@string/app_name"'),
          reason: 'U+${space.codeUnitAt(0).toRadixString(16)}',
        );
      }
    });

    test('rejects, and does not hang on, a tag it cannot read', () {
      for (final space in ['\u00a0', '\u000b', '\u2003']) {
        expect(
          () => AndroidManifestEditor.withAppLabel(
            '<manifest><application$space/></manifest>',
          ),
          throwsA(isA<MalformedResourceException>()),
        );
      }
    });

    test('rejects a manifest without an application', () {
      expect(
        () => AndroidManifestEditor.withAppLabel(
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android"/>',
        ),
        throwsA(isA<MalformedResourceException>()),
      );
    });

    test('rejects an application without a label', () {
      expect(
        () => AndroidManifestEditor.withAppLabel(
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
          '<application android:icon="@mipmap/ic_launcher"/>'
          '</manifest>',
        ),
        throwsA(isA<MalformedResourceException>()),
      );
    });

    test('rejects an empty or malformed document', () {
      expect(
        () => AndroidManifestEditor.withAppLabel(''),
        throwsA(isA<XmlException>()),
      );
      expect(
        () => AndroidManifestEditor.withAppLabel('<manifest><application'),
        throwsA(isA<XmlException>()),
      );
    });
  });

  group('AndroidManifestEditor.ownedContent', () {
    const base =
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '  <application android:label="example" android:icon="a"/>\n'
        '</manifest>\n';

    test('is the label of the application', () {
      expect(AndroidManifestEditor.ownedContent(base), 'example');
    });

    test('ignores whatever else the user changes', () {
      final edited = base
          .replaceFirst('"a"', '"b"')
          .replaceFirst('<manifest', '<!-- hi -->\n<manifest');

      expect(
        AndroidManifestEditor.ownedContent(edited),
        AndroidManifestEditor.ownedContent(base),
      );
    });

    test('follows the label', () {
      expect(
        AndroidManifestEditor.ownedContent(
          AndroidManifestEditor.withAppLabel(base),
        ),
        '@string/app_name',
      );
    });
  });
}
