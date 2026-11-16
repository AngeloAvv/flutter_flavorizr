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

/// Thrown when a target, or a member of a recipe, is neither a recipe nor a
/// processor.
class UnknownTargetException implements Exception {
  /// The name that matches no recipe and no processor.
  final String name;

  /// The closest recipe or processor, or `null` when none is close enough.
  final String? suggestion;

  /// The recipe whose member [name] is, or `null` when [name] was requested
  /// as a target.
  final String? recipe;

  UnknownTargetException(this.name, {this.suggestion, this.recipe});

  @override
  String toString() {
    final where = recipe == null
        ? 'Unknown target "$name".'
        : 'Recipe "$recipe" contains "$name", which is neither a recipe nor '
              'a processor.';

    return suggestion == null ? where : '$where Did you mean "$suggestion"?';
  }
}
