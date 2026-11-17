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

/// Identifies a shared resource, such as an opened Xcode project, that
/// processors can [FlavorizrProcessor.requires] and read back through
/// [FlavorizrContext.resource].
///
/// Two keys are equal when they have the same [name] and the same type
/// argument `T`, so `ResourceKey<int>('a')` and `ResourceKey<String>('a')`
/// are different keys.
///
/// The resource lifecycle (setup before the first consumer, teardown after the
/// last one) is built on top of it: see `Resource` and `ResourceLifecycle`.
final class ResourceKey<T> {
  /// A unique, human readable name of the resource, e.g. `xcodeproj:ios`.
  final String name;

  /// Creates a key for the resource called [name].
  const ResourceKey(this.name);

  @override
  bool operator ==(Object other) =>
      other is ResourceKey<T> &&
      other.runtimeType == runtimeType &&
      other.name == name;

  @override
  int get hashCode => Object.hash(runtimeType, name);

  @override
  String toString() => 'ResourceKey<$T>($name)';
}
