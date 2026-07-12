/*
 * Copyright (c) 2024 Angelo Cassano
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

import 'package:flutter_flavorizr/src/utils/linux_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cleanupMarkupBlock', () {
    const begin = '# ----- BEGIN FOO -----';
    const end = '# ----- END FOO -----';

    test(
      'removes a previously injected block and its surrounding blank lines',
      () {
        const content =
            'before\n'
            '\n'
            '$begin\n'
            'generated line 1\n'
            'generated line 2\n'
            '$end\n'
            '\n'
            'after';

        expect(cleanupMarkupBlock(content, begin, end), 'beforeafter');
      },
    );

    test('is a no-op when the markup block is absent', () {
      const content = 'before\nafter';

      expect(cleanupMarkupBlock(content, begin, end), content);
    });

    test('removes an empty block with no content between the markers', () {
      const content =
          'before\n'
          '\n'
          '$begin\n'
          '$end\n'
          '\n'
          'after';

      expect(cleanupMarkupBlock(content, begin, end), 'beforeafter');
    });

    test('rerunning cleanup on its own output fully removes the markers', () {
      const content =
          'before\n'
          '\n'
          '$begin\n'
          '$end\n'
          '\n'
          'after';

      final firstPass = cleanupMarkupBlock(content, begin, end);
      final secondPass = cleanupMarkupBlock(firstPass, begin, end);

      expect(firstPass, 'beforeafter');
      expect(secondPass, firstPass);
      expect(secondPass.contains(begin), isFalse);
      expect(secondPass.contains(end), isFalse);
    });

    test('supports CRLF line endings', () {
      const content =
          'before\r\n'
          '\r\n'
          '$begin\r\n'
          'generated line\r\n'
          '$end\r\n'
          '\r\n'
          'after';

      expect(cleanupMarkupBlock(content, begin, end), 'beforeafter');
    });

    test('removes multiple occurrences of the block', () {
      const content =
          'a\n'
          '$begin\n'
          'x\n'
          '$end\n'
          'b\n'
          '$begin\n'
          'y\n'
          '$end\n'
          'c';

      expect(cleanupMarkupBlock(content, begin, end), 'abc');
    });
  });

  group('stripLeadingLineBreaks', () {
    test('strips leading LF line breaks', () {
      expect(stripLeadingLineBreaks('\n\ncontent'), 'content');
    });

    test('strips leading CRLF line breaks', () {
      expect(stripLeadingLineBreaks('\r\n\r\ncontent'), 'content');
    });

    test('leaves content without leading line breaks unchanged', () {
      expect(stripLeadingLineBreaks('content'), 'content');
    });

    test('does not strip line breaks in the middle of the content', () {
      expect(stripLeadingLineBreaks('a\n\nb'), 'a\n\nb');
    });
  });

  group('escapeQuotedString', () {
    test('escapes double quotes', () {
      expect(escapeQuotedString('say "hi"'), r'say \"hi\"');
    });

    test('escapes backslashes before quotes', () {
      expect(escapeQuotedString(r'C:\path\to"file"'), r'C:\\path\\to\"file\"');
    });

    test('returns the value unchanged when nothing needs escaping', () {
      expect(escapeQuotedString('Apple App'), 'Apple App');
    });
  });
}
