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

import 'dart:convert';

import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

/// The format preserving edits flavorizr makes to the `Info.plist` of a Darwin
/// platform.
///
/// The only part of the file flavorizr owns is the value of a few `<string>`
/// entries of the top level `<dict>`: `CFBundleName`, `CFBundleDisplayName`
/// and, when a flavor has a launch screen, `UILaunchStoryboardName`. An edit
/// replaces the content of the `<string>` element in the source text and
/// nothing else: indentation, line endings, comments, the order of the keys and
/// every other entry are left exactly as the user wrote them. 2.x serialized
/// the whole document again, which reformatted it. The document is parsed to be
/// validated and to find the values, never serialized again.
abstract final class InfoPlistEditor {
  /// The key of the name of the bundle.
  static const String bundleName = 'CFBundleName';

  /// The key of the name the bundle is shown with.
  static const String bundleDisplayName = 'CFBundleDisplayName';

  /// The key of the storyboard of the launch screen.
  static const String launchStoryboardName = 'UILaunchStoryboardName';

  /// What `CFBundleName` is set to: the value every flavor defines.
  static const String bundleNameValue = r'$(BUNDLE_NAME)';

  /// What `CFBundleDisplayName` is set to: the value every flavor defines.
  static const String bundleDisplayNameValue = r'$(BUNDLE_DISPLAY_NAME)';

  /// What `UILaunchStoryboardName` is set to: the launch screen of the flavor,
  /// which each flavor defines in its xcconfig as `LAUNCH_SCREEN_NAME`.
  static const String launchStoryboardNameValue = r'$(LAUNCH_SCREEN_NAME)';

  /// What `UILaunchStoryboardName` goes back to when no flavor has a launch
  /// screen anymore: the storyboard `flutter create` makes.
  static const String defaultLaunchStoryboardNameValue = 'LaunchScreen';

  /// Returns [source] with the value of every key of [values] set to the value
  /// it maps to.
  ///
  /// [source] is returned as it is when every key already has its value.
  ///
  /// Throws a [MalformedResourceException] when the plist has no top level
  /// `<dict>`, or when a key of [values] is not in it or is not followed by a
  /// `<string>`, and an [XmlException] when it is not a well formed XML
  /// document.
  static String withStrings(String source, Map<String, String> values) {
    final entries = _readEntries(source);
    final edits = <_Edit>[];

    for (final MapEntry(:key, value: wanted) in values.entries) {
      final entry = entries[key];

      if (entry == null || !entry.readable) {
        throw MalformedResourceException(source);
      }
      if (entry.value == wanted) continue;

      edits.add(_Edit(entry, wanted));
    }

    // From the end, so that an edit never moves the ones that are left.
    edits.sort((a, b) => b.entry.start.compareTo(a.entry.start));

    var result = source;

    for (final edit in edits) {
      result = result.replaceRange(
        edit.entry.start,
        edit.entry.end,
        edit.replacement,
      );
    }

    return result;
  }

  /// The decoded value of every key of [keys] that is in the plist as a
  /// `<string>`, in the order of [keys]. A key that is not there, or whose value
  /// is not a `<string>`, is left out.
  ///
  /// Throws an [XmlException] when [source] is not a well formed XML document.
  static Map<String, String> readStrings(String source, Iterable<String> keys) {
    final entries = _readEntries(source);

    return {
      for (final key in keys)
        if (entries[key]?.readable ?? false) key: entries[key]!.value,
    };
  }

  /// The content of the iOS plist flavorizr owns: the name and the display name
  /// of the bundle, and the launch storyboard when flavorizr set it. It is what
  /// the lock hashes, so that whatever else the user edits is never drift.
  ///
  /// The launch storyboard is flavorizr's only while it has the value
  /// flavorizr gives it: with the launch screen disabled it keeps the one
  /// Flutter wrote, which is the user's. Changing it by hand takes it out of
  /// what is owned, which is a change of the hash and so a conflict.
  static String iosOwnedContent(String source) {
    final values = readStrings(source, [
      bundleName,
      bundleDisplayName,
      launchStoryboardName,
    ]);

    if (values[launchStoryboardName] != launchStoryboardNameValue) {
      values.remove(launchStoryboardName);
    }

    return _render(values);
  }

  /// The content of the macOS plist flavorizr owns: the name of the bundle.
  static String macosOwnedContent(String source) =>
      _render(readStrings(source, [bundleName]));

  /// The owned [values] as structured data, so that no value can pass for
  /// another entry. They are in the order of the keys flavorizr asks for, never
  /// the one of the plist: reordering the plist is not drift.
  static String _render(Map<String, String> values) => jsonEncode(values);

  /// The `<string>` values of the top level `<dict>` of [source], by key. The
  /// first of a key that is repeated is the one that counts, as in 2.x.
  static Map<String, _Entry> _readEntries(String source) {
    // The event parser is lenient: a document that is not well formed must
    // fail like it does when the plist is parsed into a tree.
    XmlDocument.parse(source);

    final entries = <String, _Entry>{};
    // The keys whose value was met, whatever it is: the first one counts.
    final claimed = <String>{};
    final path = <String>[];
    var foundDict = false;
    String? key;
    StringBuffer? keyText;
    _Entry? pending;
    StringBuffer? valueText;
    var unreadable = false;

    for (final event in parseEvents(source, withLocation: true)) {
      if (event is XmlStartElementEvent) {
        final parent = path.join('/');

        if (parent == 'plist' && event.name == 'dict' && !foundDict) {
          foundDict = true;

          // An empty first dictionary is all there is: a later one is not it.
          if (event.isSelfClosing) break;
        }

        if (parent == 'plist/dict' && foundDict) {
          if (event.name == 'key') {
            // A key that got no value before the next one is the first
            // occurrence all the same, and it cannot be edited.
            if (key != null && claimed.add(key)) {
              entries[key] = const _Entry.unreadable();
            }

            if (event.isSelfClosing) {
              // A self-closing key has no end event: its name is empty.
              keyText = null;
              key = '';
            } else {
              keyText = StringBuffer();
              key = null;
            }
          } else if (key != null) {
            final owner = key;
            key = null;

            // The first occurrence of a key counts, even when it is not a
            // plain string: a repeated key is never edited instead of it.
            final first = claimed.add(owner);

            if (event.name != 'string') {
              if (first) entries[owner] = const _Entry.unreadable();
            } else if (event.isSelfClosing) {
              if (first) {
                entries[owner] = _Entry(
                  '',
                  event.start!,
                  event.stop!,
                  selfClosing: true,
                );
              }
            } else if (first) {
              pending = _Entry('', event.stop!, event.stop!, key: owner);
              valueText = StringBuffer();
              unreadable = false;
            }
          }
        } else if (pending != null || valueText != null) {
          // An element inside of a `<string>`: not a plain text value.
          unreadable = true;
        }

        if (!event.isSelfClosing) path.add(event.name);

        continue;
      }

      if (event is XmlEndElementEvent) {
        if (path.isNotEmpty) path.removeLast();

        final parent = path.join('/');

        // Whatever follows the first top level dictionary is not the plist: a
        // key left without a value must not take one from a later dictionary.
        if (parent == 'plist' && event.name == 'dict' && foundDict) break;

        if (parent == 'plist/dict' && event.name == 'key' && keyText != null) {
          key = keyText.toString();
          keyText = null;
        } else if (parent == 'plist/dict' &&
            event.name == 'string' &&
            pending != null) {
          entries[pending.key!] = unreadable
              ? const _Entry.unreadable()
              : _Entry(valueText.toString(), pending.start, event.start!);

          pending = null;
          valueText = null;
          key = null;
        }

        continue;
      }

      if (event is XmlTextEvent || event is XmlCDATAEvent) {
        final text = event is XmlTextEvent
            ? event.value
            : (event as XmlCDATAEvent).value;

        if (keyText != null && path.join('/') == 'plist/dict/key') {
          keyText.write(text);
        } else if (valueText != null && path.join('/') == 'plist/dict/string') {
          valueText.write(text);
        }

        continue;
      }

      if (valueText != null &&
          (event is XmlCommentEvent || event is XmlProcessingEvent)) {
        unreadable = true;
      }
    }

    if (!foundDict) throw MalformedResourceException(source);

    return entries;
  }
}

/// A `<string>` value of the top level dict: its decoded [value] and the range
/// of the source, from [start] to [end] (exclusive), that holds it. For an
/// element that is [selfClosing] the range is the whole element, otherwise it
/// is its content.
final class _Entry {
  final String value;
  final int start;
  final int end;
  final String? key;
  final bool selfClosing;

  /// Whether the value is a plain text `<string>` that can be read and edited.
  final bool readable;

  /// An entry whose value is not a plain text `<string>`: it is the one of the
  /// key, so it is neither read nor edited, and nothing is edited in its place.
  const _Entry.unreadable()
    : value = '',
      start = 0,
      end = 0,
      key = null,
      selfClosing = false,
      readable = false;

  const _Entry(
    this.value,
    this.start,
    this.end, {
    this.key,
    this.selfClosing = false,
  }) : readable = true;
}

/// The replacement of an [entry] with a new [value].
final class _Edit {
  final _Entry entry;
  final String value;

  const _Edit(this.entry, this.value);

  String get replacement {
    final text = value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    return entry.selfClosing ? '<string>$text</string>' : text;
  }
}
