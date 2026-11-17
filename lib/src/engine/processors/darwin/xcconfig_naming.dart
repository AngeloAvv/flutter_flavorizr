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

/// What a character of the name of a flavor may be, as a regular expression
/// character class: **the** definition of it, which every place that writes or
/// reads the files of a flavor derives from.
///
/// It is any ASCII character but whitespace, a quote, a backslash, a semicolon,
/// a star, a slash and the control characters. They are the ones that cannot be
/// told apart in `project.pbxproj` from what surrounds the name (a quoted
/// `path = "..."` value ends at a quote and at a `;`, an annotation at `*/`) and
/// the ones that make a name no file name. A character that is not ASCII is
/// refused too: `dart_xcodeproj` writes the project as UTF-8 and reads it back as
/// Latin-1, so the path of `Flutter/éDebug.xcconfig` is not the same after the
/// next run. A flavor that has one is refused before anything is written,
/// instead of being written where nothing finds it again.
///
/// The whitelist of `tool/parity` spells the same class: a test keeps the two
/// the same.
const flavorNameCharacter = r'[^\s";*/\x00-\x1f\x7f-\uffff\\]';

/// The file name of the xcconfig of a flavor, as a regular expression: the
/// flavor and the mode. The xcconfigs of the templates of Flutter have no flavor
/// (`Flutter/Debug.xcconfig`), so the two are told apart.
const flavorXcconfigFile =
    '$flavorNameCharacter+(?:Debug|Profile|Release)\\.xcconfig';

final _flavorName = RegExp('^$flavorNameCharacter+\$');
final _flavorPath = RegExp('^(?:Flutter|Runner/Configs)/$flavorXcconfigFile\$');

/// Whether [name] can be the name of a flavor, which becomes part of the name of
/// its files: see [flavorNameCharacter]. `.` and `..` are refused too.
bool isValidFlavorName(String name) =>
    name != '.' && name != '..' && _flavorName.hasMatch(name);

/// Throws an [ArgumentError], before anything is written, when [name] is not
/// [isValidFlavorName].
void checkFlavorName(String name) {
  if (!isValidFlavorName(name)) {
    throw ArgumentError.value(
      name,
      'flavor',
      'cannot be used as the name of a file: it must not be empty, `.` or '
          '`..`, nor hold whitespace, control or non-ASCII characters, nor any '
          'of `" \\ ; * /`',
    );
  }
}

/// Whether [path], as a file reference of a project spells it, is the xcconfig
/// of a flavor as flavorizr names it: `Flutter/<flavor>Debug.xcconfig` (iOS) or
/// `Runner/Configs/<flavor>Debug.xcconfig` (macOS), or the same with `Profile`
/// or `Release`, whatever the flavor.
bool isFlavorXcconfigPath(String path) => _flavorPath.hasMatch(path);
