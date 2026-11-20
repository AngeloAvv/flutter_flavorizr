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

import 'package:flutter_flavorizr/src/parser/mixins/build_settings_mixin.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/darwin_icon_name.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory assets;

  setUp(() => assets = Directory.systemTemp.createTempSync('icon_name'));
  tearDown(() => assets.deleteSync(recursive: true));

  Map<String, dynamic> resolve(
    Map<String, dynamic> settings, {
    bool hasIcon = false,
    bool chosen = false,
    bool generated = false,
  }) => DarwinIconName.resolve(
    settings,
    assetsPath: assets.path,
    flavorName: 'apple',
    hasIcon: hasIcon,
    chosen: chosen,
    generated: generated,
  );

  final defaults = BuildSettingsMixin.iosDefaultBuildSettings;

  test('a flavor with no icon builds with the AppIcon of the project', () {
    expect(resolve(defaults)[DarwinIconName.setting], 'AppIcon');
  });

  test('keeps every other setting', () {
    expect(
      {...resolve(defaults)}..remove(DarwinIconName.setting),
      {...defaults}..remove(DarwinIconName.setting),
    );
  });

  test('a flavor with an icon builds with the set of its own', () {
    expect(
      resolve(defaults, hasIcon: true)[DarwinIconName.setting],
      DarwinIconName.flavorSet,
    );
  });

  test('a set that exists in the project is the one of the flavor', () {
    Directory(p.join(assets.path, 'AppIcon-apple.appiconset')).createSync();

    expect(resolve(defaults)[DarwinIconName.setting], DarwinIconName.flavorSet);
  });

  test(
    'a set that flavorizr made is not the one of the flavor, which is on its '
    'way out',
    () {
      Directory(p.join(assets.path, 'AppIcon-apple.appiconset')).createSync();

      expect(
        resolve(defaults, generated: true)[DarwinIconName.setting],
        'AppIcon',
      );
      expect(
        resolve(
          defaults,
          hasIcon: true,
          generated: true,
        )[DarwinIconName.setting],
        DarwinIconName.flavorSet,
      );
    },
  );

  test('the set of another flavor is not the one of this flavor', () {
    Directory(p.join(assets.path, 'AppIcon-banana.appiconset')).createSync();

    expect(resolve(defaults)[DarwinIconName.setting], 'AppIcon');
  });

  test('a setting the user wrote is never changed', () {
    final mine = {...defaults, DarwinIconName.setting: 'MyIcon'};

    expect(resolve(mine), mine);
    expect(resolve(mine, hasIcon: true), mine);
  });

  test('a user who wrote the default itself keeps it', () {
    expect(
      resolve(defaults, chosen: true)[DarwinIconName.setting],
      DarwinIconName.flavorSet,
    );
  });

  test('settings with no icon name are left as they are', () {
    expect(resolve({'A': 'b'}), {'A': 'b'});
  });
}
