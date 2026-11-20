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

import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';

/// The key under which the lock remembers that flavorizr **created** a patched
/// file (see [recordCreated]).
const createdKey = 'created';

/// Reads what a patched file holds that is **not** its owned part, nor what the
/// tools around it (Xcode, Flutter) add on their own: the part only the user can
/// have changed.
///
/// It is the counterpart of the reader of the owned content (what the lock
/// hashes), and it is how a file flavorizr made is told from one the user
/// edited.
typedef ForeignReader = String Function(String source);

/// The digest of what [read] makes of [bytes], a text file that may start with a
/// byte order mark, which never matters.
String foreignDigest(ForeignReader read, List<int> bytes) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final source = text.startsWith('﻿') ? text.substring(1) : text;

  return digestOf(utf8.encode(read(source)));
}

/// Remembers, in the lock, that the processor of [ctx] **created** the patched
/// file at [path], with [bytes] as its content: the digest of what [read] makes
/// of it.
///
/// A patched file belongs to the user, who may have had it before flavorizr
/// existed, so when its flavor is dropped it is left in place. A file flavorizr
/// made is the exception, and this is what tells it: the file is deleted along
/// with its flavor as long as what [read] makes of it is still what is
/// recorded, i.e. the user, Xcode and Flutter only changed the owned part and
/// what they add on their own. Anything else is a conflict, and the user
/// decides: see `planDeletions`.
///
/// It is recorded as a key of the file (`FlavorizrContext.ownKeys`), so a run
/// that finds the file again and patches it must **not** call this: the lock
/// keeps what it has, and the file is still the one flavorizr created. Call it
/// only when the file did not exist.
void recordCreated(
  FlavorizrContext ctx,
  String path,
  ForeignReader read,
  List<int> bytes,
) => ctx.ownKeys(path, {createdKey: foreignDigest(read, bytes)});
