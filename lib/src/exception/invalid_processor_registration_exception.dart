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

/// The namespaces of the processors of flavorizr. A processor of the user
/// cannot take an id in one, unless it replaces a processor that has it.
const reservedNamespaces = {
  'android',
  'ios',
  'macos',
  'linux',
  'windows',
  'flutter',
  'google',
  'huawei',
  'ide',
};

/// Thrown when a processor of the user is registered in a way that is not
/// allowed: in a namespace of flavorizr, or as an override of a processor that
/// flavorizr does not have.
class InvalidProcessorRegistrationException implements Exception {
  /// The id of the processor.
  final String id;

  /// Why the registration is refused.
  final String reason;

  InvalidProcessorRegistrationException.reserved(this.id)
    : reason =
          'the "${id.split(':').first}" namespace is reserved for the '
          'processors of flavorizr. Use a namespace of your own, such as '
          '"acme:${id.contains(':') ? id.split(':').skip(1).join(':') : id}", '
          'or pass the processor in `overrides` to replace the one that has '
          'this id';

  InvalidProcessorRegistrationException.notBuiltIn(this.id)
    : reason =
          'it is registered in `overrides`, but flavorizr has no processor '
          'with this id to replace. Pass it in `processors` instead';

  @override
  String toString() => 'Processor "$id" cannot be registered: $reason.';
}
