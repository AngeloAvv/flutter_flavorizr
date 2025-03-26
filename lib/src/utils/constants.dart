/*
 * Copyright (c) 2024 Angelo Cassano
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

class K {
  static const String androidAppPath = 'android/app';

  static const String androidSrcPath = '$androidAppPath/src';

  static const String androidIconPath = '$androidAppPath/src/%s/res/%s/ic_launcher.png';

  static const String androidAdaptiveIconBackgroundPath = '$androidAppPath/src/%s/res/%s/ic_launcher_background.png';

  static const String androidAdaptiveIconForegroundPath = '$androidAppPath/src/%s/res/%s/ic_launcher_foreground.png';

  static String androidAdaptiveIconMonochromePath =
      '$androidAppPath/src/%s/res/%s/ic_launcher_monochrome.png';

  static const String androidAdaptiveIconXmlPath = '$androidAppPath/src/%s/res/mipmap-anydpi-v26/ic_launcher.xml';

  static const String androidManifestPath = '$androidSrcPath/main/AndroidManifest.xml';

  static const String androidBuildKotlinPath = '$androidAppPath/build.gradle.kts';
  static const String androidBuildLegacyPath = '$androidAppPath/build.gradle';

  static const String androidFlavorizrLegacyName = 'flavorizr.gradle';
  static const String androidFlavorizrKotlinName = 'flavorizr.gradle.kts';

  static const String androidFlavorizrLegacyPath = '$androidAppPath/$androidFlavorizrLegacyName';
  static const String androidFlavorizrKotlinPath = '$androidAppPath/$androidFlavorizrKotlinName';

  static const String flutterPath = 'lib';

  static const String flutterFlavorPath = '$flutterPath/flavors.dart';

  static const String flutterAppPath = '$flutterPath/app.dart';

  static const String flutterMainPath = '$flutterPath/main.dart';

  static const String flutterPagesPath = '$flutterPath/pages';

  static const String flutterMainPagePath = '$flutterPagesPath/my_home_page.dart';

  static const String iOSPath = 'ios';

  static const String iOSFlutterPath = '$iOSPath/Flutter';

  static const String iOSRunnerPath = '$iOSPath/Runner';

  static const String iOSRunnerProjectPath = '$iOSPath/Runner.xcodeproj';

  static const String iOSPodfilePath = '$iOSPath/Podfile';

  static const String iOSPListPath = '$iOSRunnerPath/Info.plist';

  static const String iOSAssetsPath = '$iOSRunnerPath/Assets.xcassets';

  static const String iOSAppIconPath = '$iOSAssetsPath/%sAppIcon.appiconset/%s';

  static const String iOSFirebaseScriptPath = '$iOSPath/firebaseScript.sh';

  static const String macOSPath = 'macos';

  static const String macOSRunnerPath = '$macOSPath/Runner';

  static const String macOSRunnerProjectPath = '$macOSPath/Runner.xcodeproj';

  static const String macOSPodfilePath = '$macOSPath/Podfile';

  static const String macOSPlistPath = '$macOSRunnerPath/Info.plist';

  static const String macOSAssetsPath = '$macOSRunnerPath/Assets.xcassets';

  static const String macOSAppIconPath = '$macOSAssetsPath/%sAppIcon.appiconset/%s';

  static const String macOSConfigsPath = '$macOSRunnerPath/Configs';

  static const String macOSFlutterPath = '$macOSPath/Flutter';

  static const String macOSFirebaseScriptPath = '$macOSPath/firebaseScript.sh';

  static const String assetsZipPath = 'assets.tmp.zip';

  static const String tempPath = '.tmp';

  static const String tempAndroidPath = '$tempPath/android';

  static const String tempAndroidResPath = '$tempAndroidPath/res';

  static const String tempFlutterPath = '$tempPath/flutter';

  static const String tempFlutterAppPath = '$tempFlutterPath/app.dart';

  static const String tempFlutterMainPath = '$tempFlutterPath/main.dart';

  static const String tempFlutterPagesPath = '$tempFlutterPath/pages';

  static const String tempiOSPath = '$tempPath/ios';

  static const String tempiOSAssetsPath = '$tempiOSPath/Assets.xcassets';

  static const String tempiOSLaunchScreenPath = '$tempiOSPath/LaunchScreen.storyboard';

  static const String tempScriptsPath = '$tempPath/scripts';

  static const String tempDarwinScriptsPath = '$tempScriptsPath/darwin';

  static const String tempMacOSPath = '$tempPath/macos';

  static const String tempMacOSScriptsPath = '$tempScriptsPath/macos';

  static const String tempMacOSAssetsPath = '$tempMacOSPath/Assets.xcassets';

  static const String tempDarwinCreateSchemeScriptPath = '$tempDarwinScriptsPath/create_scheme.rb';

  static const String tempiOSScriptsPath = '$tempScriptsPath/ios';

  static const String tempDarwinAddFileScriptPath = '$tempDarwinScriptsPath/add_file.rb';

  static const String tempDarwinAddBuildConfigurationScriptPath = '$tempDarwinScriptsPath/add_build_configuration.rb';

  static const String tempDarwinAddFirebaseBuildPhaseScriptPath = '$tempDarwinScriptsPath/add_firebase_build_phase.rb';

  static const String ideaPath = '.idea';

  static const String ideaLaunchpath = '$ideaPath/runConfigurations';

  static const String vsCodePath = '.vscode';

  static const String vsCodeLaunchPath = '$vsCodePath/launch.json';

  const K._();
}
