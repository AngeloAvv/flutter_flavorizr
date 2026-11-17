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

/// Thrown when a call that sets the title of the Linux window is a statement
/// that a control flow statement governs without braces, such as
///
/// ```c
/// if (enabled)
///   gtk_window_set_title(window, "title");
/// ```
///
/// The region flavorizr writes after the call would be a separate statement, so
/// it would run whatever the condition says. flavorizr does not guess: nothing
/// is written.
class UnsafeTitleSetterException implements Exception {
  /// The call, as the file has it.
  final String statement;

  /// Creates the exception for [statement].
  UnsafeTitleSetterException(this.statement);

  @override
  String toString() =>
      'Cannot flavor `${statement.trim()}` in linux/runner/my_application.cc: '
      'the statement is controlled by an `if`, `else`, `for` or `while` with '
      'no braces, so the code flavorizr adds after it would run whatever the '
      'condition says.\n'
      'Put the statement between braces ({ ... }) and run flavorizr again.';
}
