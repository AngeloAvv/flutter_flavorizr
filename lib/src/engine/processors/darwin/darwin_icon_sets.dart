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

import 'package:flutter_flavorizr/src/models/darwin/icon/darwin_icon.dart';
import 'package:flutter_flavorizr/src/models/darwin/icon/darwin_idiom.dart';
import 'package:flutter_flavorizr/src/models/ios/ios_icon.dart';
import 'package:flutter_flavorizr/src/models/macos/macos_icon.dart';

/// The icons of the `AppIcon-<flavor>.appiconset` of an iOS flavor: the sizes
/// Xcode asks for an iPhone, an iPad and the App Store.
const iosIconSet = <DarwinIcon>[
  IosIcon(size: 20, idiom: DarwinIdiom.iPhone, scale: 2),
  IosIcon(size: 20, idiom: DarwinIdiom.iPhone, scale: 3),
  IosIcon(size: 29, idiom: DarwinIdiom.iPhone, scale: 1),
  IosIcon(size: 29, idiom: DarwinIdiom.iPhone, scale: 2),
  IosIcon(size: 29, idiom: DarwinIdiom.iPhone, scale: 3),
  IosIcon(size: 40, idiom: DarwinIdiom.iPhone, scale: 2),
  IosIcon(size: 40, idiom: DarwinIdiom.iPhone, scale: 3),
  IosIcon(size: 60, idiom: DarwinIdiom.iPhone, scale: 2),
  IosIcon(size: 60, idiom: DarwinIdiom.iPhone, scale: 3),
  IosIcon(size: 20, idiom: DarwinIdiom.iPad, scale: 1),
  IosIcon(size: 20, idiom: DarwinIdiom.iPad, scale: 2),
  IosIcon(size: 29, idiom: DarwinIdiom.iPad, scale: 1),
  IosIcon(size: 29, idiom: DarwinIdiom.iPad, scale: 2),
  IosIcon(size: 40, idiom: DarwinIdiom.iPad, scale: 1),
  IosIcon(size: 40, idiom: DarwinIdiom.iPad, scale: 2),
  IosIcon(size: 76, idiom: DarwinIdiom.iPad, scale: 1),
  IosIcon(size: 76, idiom: DarwinIdiom.iPad, scale: 2),
  IosIcon(size: 83.5, idiom: DarwinIdiom.iPad, scale: 2),
  IosIcon(size: 1024, idiom: DarwinIdiom.iosMarketing, scale: 1),
];

/// The icons of the `AppIcon-<flavor>.appiconset` of a macOS flavor. The 2x of
/// a size is the 1x of the next one, so they share a file.
const macosIconSet = <DarwinIcon>[
  MacosIcon(size: 16, idiom: DarwinIdiom.mac, scale: 1),
  MacosIcon(size: 16, idiom: DarwinIdiom.mac, scale: 2),
  MacosIcon(size: 32, idiom: DarwinIdiom.mac, scale: 1),
  MacosIcon(size: 32, idiom: DarwinIdiom.mac, scale: 2),
  MacosIcon(size: 128, idiom: DarwinIdiom.mac, scale: 1),
  MacosIcon(size: 128, idiom: DarwinIdiom.mac, scale: 2),
  MacosIcon(size: 256, idiom: DarwinIdiom.mac, scale: 1),
  MacosIcon(size: 256, idiom: DarwinIdiom.mac, scale: 2),
  MacosIcon(size: 512, idiom: DarwinIdiom.mac, scale: 1),
  MacosIcon(size: 512, idiom: DarwinIdiom.mac, scale: 2),
];

/// The `Contents.json` of an appiconset of [icons], which is what Xcode reads to
/// know which file is which icon.
///
/// It is the text 2.x wrote, byte for byte, so that a project 2.x flavorized
/// has the same file as the one 3.0 makes.
String darwinIconContents(Iterable<DarwinIcon> icons) => jsonEncode({
  'images': [for (final icon in icons) icon.toJson()],
  'info': {'version': 1, 'author': 'xcode'},
});
