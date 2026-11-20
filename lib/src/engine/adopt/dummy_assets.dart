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

import 'package:crypto/crypto.dart';

/// The placeholder assets that flavorizr 2.x copied into the project for a
/// flavor with `generateDummyAssets`, by the hash of their bytes.
///
/// 3.0 no longer bundles them (a flavor with no icon uses the default icon of
/// the project), so what is left of them in a project is only recognised by
/// hash: one that still has the bytes 2.x wrote was never touched, and is
/// flavorizr's to manage; one that has other bytes was replaced by the user,
/// and is theirs.
///
/// The table is keyed by the path of the asset in the 2.x `assets` folder, which
/// is not the path in the project: [flavorPaths] tells where 2.x put each of
/// them for a flavor.
final class DummyAssets {
  /// The assets of 2.6, the last release that wrote them.
  static final v2 = DummyAssets(_v2Hashes);

  /// Where 2.x put the files of a folder of the assets, for a flavor `{f}`.
  static const _placement = [
    ('android/res/', 'android/app/src/{f}/res/'),
    (
      'ios/Assets.xcassets/AppIcon.appiconset/',
      'ios/Runner/Assets.xcassets/AppIcon-{f}.appiconset/',
    ),
    (
      'ios/Assets.xcassets/LaunchImage.imageset/',
      'ios/Runner/Assets.xcassets/{f}LaunchImage.imageset/',
    ),
    ('ios/LaunchScreen.storyboard', 'ios/Runner/{f}LaunchScreen.storyboard'),
    (
      'macos/Assets.xcassets/AppIcon.appiconset/',
      'macos/Runner/Assets.xcassets/AppIcon-{f}.appiconset/',
    ),
    ('windows/app_icon.ico', 'windows/runner/resources/{f}.ico'),
  ];

  final Map<String, String> _hashes;

  /// A table of [hashes], the sha256 in hex of each asset by its path in the
  /// assets of 2.x, such as `android/res/mipmap-hdpi/ic_launcher.png`.
  DummyAssets(Map<String, String> hashes) : _hashes = Map.unmodifiable(hashes);

  /// The sha256 of [bytes] in hex, the way the table writes it.
  static String hashOf(List<int> bytes) => sha256.convert(bytes).toString();

  /// The files 2.x wrote for [flavor], by path relative to the project, with the
  /// hash of the bytes it wrote.
  ///
  /// With a [platform] (`android`, `ios`, `macos` or `windows`), only the ones of that
  /// platform: the ones of the others are not asked about. A platform that has
  /// no dummy assets has no files. [flavor] must be a name that is safe to use in
  /// a path.
  Map<String, String> flavorPaths(String flavor, {String? platform}) {
    final paths = <String, String>{};

    for (final MapEntry(key: asset, value: hash) in _hashes.entries) {
      if (platform != null && !asset.startsWith('$platform/')) continue;

      for (final (from, to) in _placement) {
        // A folder (with the trailing `/`) holds what is below it; a file is
        // only itself.
        if (from.endsWith('/') ? asset.startsWith(from) : asset == from) {
          paths[to.replaceAll('{f}', flavor) + asset.substring(from.length)] =
              hash;
          break;
        }
      }
    }

    return paths;
  }
}

/// The hashes of what 2.6 wrote. The one of Windows is not the one of a file that
/// 2.x copied but of the `.ico` it built from its `windows/app_icon.ico`, which
/// is the same for every flavor: it is the one that the golden project of 2.6.0
/// records for them.
const _v2Hashes = {
  'android/res/mipmap-hdpi/ic_launcher.png':
      '6a7c8f0d703e3682108f9662f813302236240d3f8f638bb391e32bfb96055fef',
  'android/res/mipmap-mdpi/ic_launcher.png':
      'c7c0c0189145e4e32a401c61c9bdc615754b0264e7afae24e834bb81049eaf81',
  'android/res/mipmap-xhdpi/ic_launcher.png':
      'e14aa40904929bf313fded22cf7e7ffcbf1d1aac4263b5ef1be8bfce650397aa',
  'android/res/mipmap-xxhdpi/ic_launcher.png':
      '4d470bf22d5c17d84edc5f82516d1ba8a1c09559cd761cefb792f86d9f52b540',
  'android/res/mipmap-xxxhdpi/ic_launcher.png':
      '3c34e1f298d0c9ea3455d46db6b7759c8211a49e9ec6e44b635fc5c87dfb4180',
  'ios/Assets.xcassets/AppIcon.appiconset/Contents.json':
      '3b1e214f466ffedff74baa5598ad5c4421130eea6bc8d57b8fe23435e8280ae4',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png':
      '7770183009e914112de7d8ef1d235a6a30c5834424858e0d2f8253f6b8d31926',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png':
      '5925dab509451f9ecbb12ce8a625f9d4c104718ee20caff8b1b51032d1cd8946',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png':
      'c4d9a284c12301d0f50e248ec53ed51a19a10147b774b23308399250b0d44c55',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png':
      'bf97f9d3233f33e1389b09f7b8add53741300cb834d6c7a5ca32cbed363a4fb2',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png':
      '285442f69a06b45d9d79df80321815b546473548a37b78819b68959c7b8ed237',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png':
      '2ab64af8ac727ea99c6ab9eaff847f46fbf2a9a0a78a0abcbf3180f3851645b4',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png':
      '9dca09f4e5ed5684d3c4dff41f4e8b7cb864b438172d72be069315fa362930f9',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png':
      'c4d9a284c12301d0f50e248ec53ed51a19a10147b774b23308399250b0d44c55',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png':
      'd5ad04de321ef37cacc5a7b960afcce71bdcb96fa020c48249c1545dd1a0f497',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png':
      '809abfe75c440770c13c4e2e46d09603c22053e9d4e0e2275dcb9c1dcfbb2c75',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png':
      '809abfe75c440770c13c4e2e46d09603c22053e9d4e0e2275dcb9c1dcfbb2c75',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png':
      '3db08cb79e7b01b9e81f956e3a0ae10148d0fafde3ea7aa70048df905aa52cfd',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png':
      '23c13d463f5dca5c1f14a14934003601c29f1218fd461016d8a22cef579a665f',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png':
      '6db7726530d71d3f52cb59793eb691313baa04796e129e1e043c0a58a1bffd2f',
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png':
      'cee565f5e62116569b64980b209fd5ca4b3d3739011f5343250b33a1a2c6eb65',
  'ios/Assets.xcassets/LaunchImage.imageset/Contents.json':
      'ccc7950fd5f5b82067c85f667940a9d59189151460761ece8098ca78daa19469',
  'ios/Assets.xcassets/LaunchImage.imageset/LaunchImage.png':
      '93ae7d494fad0fb30cbf3ae746a39c4bc7a0f8bbf87fbb587a3f3c01f3c5ce20',
  'ios/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png':
      '93ae7d494fad0fb30cbf3ae746a39c4bc7a0f8bbf87fbb587a3f3c01f3c5ce20',
  'ios/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png':
      '93ae7d494fad0fb30cbf3ae746a39c4bc7a0f8bbf87fbb587a3f3c01f3c5ce20',
  'ios/Assets.xcassets/LaunchImage.imageset/README.md':
      'a985b626c4f7546a8ba392d135e9226c3547c8e2b46895f5f2bdf40d7b14ef9f',
  'ios/LaunchScreen.storyboard':
      '4ccc04769c3fc2f52f90c4e52345c9e094a9fb9e79745aafe2b317729ee20626',
  'macos/Assets.xcassets/AppIcon.appiconset/Contents.json':
      'bc6ba8105ca69651aeeb77358851590de295dca04681a1d58c0f449641c242f3',
  'macos/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png':
      'b18bebaad1ad6724e48bcdf699ba3927df3f258febe646a3ab5c62767c6bab40',
  'macos/Assets.xcassets/AppIcon.appiconset/app_icon_128.png':
      'f90d839a289ecadbf2b0b3400da43eb808b84908335ae4a007457c4d5a56a57c',
  'macos/Assets.xcassets/AppIcon.appiconset/app_icon_16.png':
      '592c2abf84adb2d391aed8b634d3233e2c65369f06018dcd8a4b27ba755edcbe',
  'macos/Assets.xcassets/AppIcon.appiconset/app_icon_256.png':
      '75d9a0c034113ca8a1ec11c24b81f2086630a5a5c65c7d26a5dc03a1c0a4478c',
  'macos/Assets.xcassets/AppIcon.appiconset/app_icon_32.png':
      'a896e65745557732c72bd4ee3a10782fe2aa95590b5af659869e5808db9c01c1',
  'macos/Assets.xcassets/AppIcon.appiconset/app_icon_512.png':
      '3a69a8a1aac5d9a8374492af4b6d07a4ce637659eb24a7849c4dfb261d75c6a3',
  'macos/Assets.xcassets/AppIcon.appiconset/app_icon_64.png':
      'd29d4e0af9256dc92d0a8f8810608a5e64a132ad8b397ca2c4ddc0b1c26a68c3',
  'windows/app_icon.ico':
      '4905ee2a6a9a10857f1f4c15d88479f0dc9c810f8d648653ac4e3e3bfb2784fc',
};
