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

/// Thrown when a call that sets the title of the Linux window cannot be given
/// a region right after it, because the region would not do what the call does.
///
/// Whatever governs the call without being a block, such as
///
/// ```c
/// if (enabled)
///   gtk_window_set_title(window, "title");
/// ```
///
/// is not a block the region would be in, and neither is a call that shares its
/// line with other code, or that is followed by a comment that goes on past
/// its line, which the region would end up in. flavorizr does not guess:
/// nothing is written.
class UnsafeTitleSetterException implements Exception {
  /// The statement, as the file has it.
  final String statement;

  /// Creates the exception for [statement].
  UnsafeTitleSetterException(this.statement);

  @override
  String toString() =>
      'Cannot flavor `${statement.replaceAll(RegExp(r'\s+'), ' ')}` in '
      'linux/runner/my_application.cc: flavorizr adds its code on the line '
      'after the statement, and here that would not be the same as being '
      'the statement.\n'
      'Make the statement one of its own: put it between braces ({ ... }) if '
      'an `if`, `else`, `for`, `while`, `do`, `case` or label comes before it, '
      'give it a line of its own, and close any comment after it on that line. '
      'Then run flavorizr again.';
}
