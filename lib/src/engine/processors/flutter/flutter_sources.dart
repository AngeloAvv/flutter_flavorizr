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

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';

// The Dart sources the Flutter processors write. They live in code, so that
// nothing has to be downloaded, or read from a folder of the package.

/// Makes [text] safe to put between single quotes in Dart source.
String dartStringContent(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$')
    .replaceAll('\r', r'\r')
    .replaceAll('\n', r'\n');

/// `lib/flavors.g.dart`: the `Flavor` enum, and `F`, which tells which flavor
/// the app was built as and holds what `flavorizr.yaml` says about it.
///
/// The flavor comes from `appFlavor` of `package:flutter/services.dart`, which
/// is what `--flavor` sets, and it is looked up by the name the flavor has in
/// `flavorizr.yaml`, exactly as it was written. The members of the enum are
/// lower-cased, as Dart code expects, so comparing their names with
/// `appFlavor` (what 2.x did) never matched a flavor named `Apple`.
String flavorsGeneratedSource(Flavorizr config) {
  final flavors = config.flavors;
  final names = dartStringContent(flavors.keys.join(', '));
  final members = [
    for (final name in flavors.keys)
      "${name.toLowerCase()}('${dartStringContent(name)}')",
  ];
  final titles = [
    for (final MapEntry(key: name, value: flavor) in flavors.entries)
      '      case Flavor.${name.toLowerCase()}:\n'
          "        return '${dartStringContent(flavor.app.name)}';",
  ];

  return '''
// GENERATED CODE - DO NOT MODIFY BY HAND.
//
// flutter_flavorizr writes this file from flavorizr.yaml, and writes it again
// whenever the flavors change. Put your own code in flavors.dart, which
// exports this file and which flutter_flavorizr never overwrites.

import 'package:flutter/services.dart' as services;

enum Flavor {
  ${members.join(',\n  ')};

  const Flavor(this.flavorName);

  /// The name of the flavor in flavorizr.yaml: what `--flavor` takes and
  /// `appFlavor` returns, casing included.
  final String flavorName;
}

class F {
  F._();

  /// The flavor the app was built as.
  ///
  /// Throws a [StateError] when the app was built without a flavor, or with
  /// one that flavorizr.yaml does not define.
  static Flavor get appFlavor {
    final name = services.appFlavor;

    if (name == null) {
      throw StateError(
        'The app was built without a flavor. Build or run it with '
        '--flavor <name>, where <name> is one of: $names.',
      );
    }

    for (final flavor in Flavor.values) {
      if (flavor.flavorName == name) return flavor;
    }

    throw StateError(
      'The app was built with the flavor "\$name", which flavorizr.yaml does '
      'not define. Its flavors are: $names.',
    );
  }

  static String get name => appFlavor.name;

  static String get title {
    switch (appFlavor) {
${titles.join('\n')}
    }
  }
}
''';
}

/// `lib/flavors.dart`: the file of the user, created once.
const String flavorsScaffoldSource = '''
// This file is yours: flutter_flavorizr creates it once and never writes it
// again. Add what you need around the flavors, such as colors or URLs by
// flavor.
//
// The Flavor enum and F live in flavors.g.dart, which flutter_flavorizr
// writes again whenever the flavors change.

export 'flavors.g.dart';
''';

/// `lib/main.dart` of a new app.
///
/// It initializes nothing: `F.appFlavor` reads the flavor the app was built as.
const String mainScaffoldSource = '''
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runApp(const App());
}
''';

/// `lib/app.dart` of a new app.
const String appScaffoldSource = '''
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'flavors.dart';
import 'pages/my_home_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: F.title,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _flavorBanner(child: MyHomePage(), show: kDebugMode),
    );
  }

  Widget _flavorBanner({required Widget child, bool show = true}) => show
      ? Banner(
          location: BannerLocation.topStart,
          message: F.name,
          color: Colors.green.withAlpha(150),
          textStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.0,
            letterSpacing: 1.0,
          ),
          textDirection: TextDirection.ltr,
          child: child,
        )
      : Container(child: child);
}
''';

/// `lib/pages/my_home_page.dart` of a new app.
const String homePageScaffoldSource = '''
import 'package:flutter/material.dart';
import '../flavors.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(F.title)),
      body: Center(child: Text('Hello \${F.title}')),
    );
  }
}
''';
