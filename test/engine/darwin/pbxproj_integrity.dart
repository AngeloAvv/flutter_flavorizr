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

/// What the tests need to tell that a `project.pbxproj` is sound, from the text
/// of the file alone, so that it does not depend on what `dart_xcodeproj` does
/// with a reference it cannot resolve when it opens a project.
library;

final _uuid = RegExp(r'\b(?:[0-9A-F]{32}|[0-9A-F]{24})\b');
final _definition = RegExp(
  r'^\t\t([0-9A-F]{32}|[0-9A-F]{24})(?: /\*.*?\*/)? = \{',
  multiLine: true,
);

/// The UUIDs of the objects [pbxproj] defines.
Set<String> objectUuids(String pbxproj) => {
  for (final match in _definition.allMatches(pbxproj)) match.group(1)!,
};

/// The UUIDs [pbxproj] mentions and defines no object for: what a removal that
/// leaves a reference behind looks like.
Set<String> danglingUuids(String pbxproj) =>
    _uuid.allMatches(pbxproj).map((match) => match.group(0)!).toSet()
      ..removeAll(objectUuids(pbxproj));
