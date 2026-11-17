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

import 'dart:io';

import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_sources.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/enums.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/flavor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

typedef _Render =
    String Function(
      Flavorizr config,
      String flavorName,
      Flavor flavor,
      Target target,
    );

/// A flavor of the configuration at [resource], rendered by [render].
void _expectSource(
  _Render render, {
  required String resource,
  required String pubspec,
  required String matcher,
  Target target = Target.debug,
  bool last = false,
}) {
  final config = TestUtils.parseFlavorizr('$resource/$pubspec');
  final name = last ? config.flavors.keys.last : config.flavors.keys.first;

  // The fixtures differ in their line endings and in the last one, which the
  // parity harness (byte for byte against 2.6.0) takes care of.
  expect(
    TestUtils.stripEndOfLines(
      render(config, name, config.flavors[name]!, target),
    ),
    TestUtils.stripEndOfLines(File('$resource/$matcher').readAsStringSync()),
  );
}

void main() {
  group('the flavor xcconfig of iOS', () {
    const resource = 'test_resources/ios/xcconfig_processor_test';

    test('includes Pods optionally, and Generated', () {
      _expectSource(
        iosXcconfigSource,
        resource: resource,
        pubspec: 'pubspec_without_variables',
        matcher: 'matcher_without_variables.xcconfig',
        last: true,
      );
    });

    test('keeps `#include?` for the Pods xcconfig, which may not exist', () {
      final config = TestUtils.parseFlavorizr(
        '$resource/pubspec_without_variables',
      );
      final name = config.flavors.keys.first;

      final source = iosXcconfigSource(
        config,
        name,
        config.flavors[name]!,
        Target.profile,
      );

      expect(
        source.split('\n').first,
        '#include? "Pods/Target Support Files/Pods-Runner/'
        'Pods-Runner.release.xcconfig"',
      );
    });

    test('appends the variables of the flavor', () {
      _expectSource(
        iosXcconfigSource,
        resource: resource,
        pubspec: 'pubspec_with_variables',
        matcher: 'matcher_with_variables.xcconfig',
      );
    });

    test('appends only the variables of the target', () {
      _expectSource(
        iosXcconfigSource,
        resource: resource,
        pubspec: 'pubspec_with_variables_and_target',
        matcher: 'matcher_with_variables_and_target.xcconfig',
        target: Target.release,
      );
    });

    test('includes the files of the app', () {
      _expectSource(
        iosXcconfigSource,
        resource: resource,
        pubspec: 'pubspec_with_global_includes',
        matcher: 'matcher_with_global_includes.xcconfig',
      );
    });

    test('includes the files of the flavor', () {
      _expectSource(
        iosXcconfigSource,
        resource: resource,
        pubspec: 'pubspec_with_flavor_includes',
        matcher: 'matcher_with_flavor_includes.xcconfig',
      );
    });

    test('includes the files of the target, optional or not', () {
      _expectSource(
        iosXcconfigSource,
        resource: resource,
        pubspec: 'pubspec_with_includes_and_target',
        matcher: 'matcher_with_includes_and_target.xcconfig',
        target: Target.release,
      );
    });
  });

  group('the flavor xcconfig of macOS, in Flutter', () {
    const resource = 'test_resources/macos/xcconfig_processor_test';

    test('includes Pods optionally, and the generated Flutter one', () {
      _expectSource(
        macosFlutterXcconfigSource,
        resource: resource,
        pubspec: 'pubspec_without_variables',
        matcher: 'matcher_without_variables.xcconfig',
      );
    });

    test('includes the files of the app', () {
      _expectSource(
        macosFlutterXcconfigSource,
        resource: resource,
        pubspec: 'pubspec_with_global_includes',
        matcher: 'matcher_with_global_includes.xcconfig',
      );
    });

    test('includes the files of the flavor', () {
      _expectSource(
        macosFlutterXcconfigSource,
        resource: resource,
        pubspec: 'pubspec_with_flavor_includes',
        matcher: 'matcher_with_flavor_includes.xcconfig',
      );
    });

    test('includes the files of the target, optional or not', () {
      _expectSource(
        macosFlutterXcconfigSource,
        resource: resource,
        pubspec: 'pubspec_with_includes_and_target',
        matcher: 'matcher_with_includes_and_target.xcconfig',
        target: Target.release,
      );
    });
  });

  group('the flavor xcconfig of macOS, in Runner/Configs', () {
    test('includes the one of Flutter and the warnings', () {
      _expectSource(
        macosConfigsXcconfigSource,
        resource: 'test_resources/macos/configs_processor_test',
        pubspec: 'pubspec',
        matcher: 'matcher_apple_debug.xcconfig',
      );
    });
  });

  group('the name of a flavor xcconfig', () {
    test('is the flavor followed by the capitalized target', () {
      expect(xcconfigName('apple', Target.debug), 'appleDebug.xcconfig');
      expect(xcconfigName('apple', Target.profile), 'appleProfile.xcconfig');
      expect(xcconfigName('apple', Target.release), 'appleRelease.xcconfig');
    });
  });
}
