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

/// What the lock recorded about a file a processor generated from inputs: the
/// hash of the file as it was written, and the hash of the inputs it was
/// generated from (see `ManagedArtifact.inputs`).
///
/// It is what `FlavorizrContext.isGeneratedFrom` compares a run with.
final class RecordedOutput {
  /// The hash of the content of the file, as the lock records it.
  final String hash;

  /// The hash of the inputs the file was generated from.
  final String inputs;

  /// Creates the record of a generated file.
  const RecordedOutput({required this.hash, required this.inputs});

  @override
  bool operator ==(Object other) =>
      other is RecordedOutput && other.hash == hash && other.inputs == inputs;

  @override
  int get hashCode => Object.hash(hash, inputs);

  @override
  String toString() => 'RecordedOutput($hash, inputs: $inputs)';
}
