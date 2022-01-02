/*
 * Copyright (c) 2022 MyLittleSuite
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
  static String androidAppPath = 'android/app';

  static String androidSrcPath = '$androidAppPath/src';

  static String androidIconPath =
      '$androidAppPath/src/%s/res/%s/ic_launcher.png';

  static String androidManifestPath =
      '$androidSrcPath/main/AndroidManifest.xml';

  static String androidBuildGradlePath = '$androidAppPath/build.gradle';

  static String flutterPath = 'lib';

  static String flutterFlavorPath = '$flutterPath/flavors.dart';

  static String flutterAppPath = '$flutterPath/app.dart';

  static String flutterPagesPath = '$flutterPath/pages';

  static String flutterMainPagePath = '$flutterPagesPath/my_home_page.dart';

  static String iOSPath = 'ios';

  static String iOSFlutterPath = '$iOSPath/Flutter';

  static String iOSRunnerPath = '$iOSPath/Runner';

  static String iOSRunnerProjectPath = '$iOSPath/Runner.xcodeproj';

  static String iOSPListPath = '$iOSRunnerPath/Info.plist';

  static String iOSAssetsPath = '$iOSRunnerPath/Assets.xcassets';

  static String iOSAppIconPath =
      '$iOSRunnerPath/Assets.xcassets/%sAppIcon.appiconset/%s';

  static String assetsZipPath = 'assets.tmp.zip';

  static String tempPath = '.tmp';

  static String tempAndroidPath = '$tempPath/android';

  static String tempAndroidResPath = '$tempAndroidPath/res';

  static String tempFlutterPath = '$tempPath/flutter';

  static String tempFlutterAppPath = '$tempFlutterPath/app.dart';

  static String tempFlutterMainPath = '$tempFlutterPath/main-target.dart';

  static String tempFlutterPagesPath = '$tempFlutterPath/pages';

  static String tempiOSPath = '$tempPath/ios';

  static String tempiOSAssetsPath = '$tempiOSPath/Assets.xcassets';

  static String tempiOSLaunchScreenPath =
      '$tempiOSPath/LaunchScreen.storyboard';

  static String tempiOSFirebaseScriptPath = '$tempiOSPath/firebaseScript.sh';

  static String tempScriptsPath = '$tempPath/scripts';

  static String tempiOSScriptsPath = '$tempScriptsPath/ios';

  static String tempiOSCreateSchemeScriptPath =
      '$tempiOSScriptsPath/create_scheme.rb';

  static String tempiOSAddFileScriptPath = '$tempiOSScriptsPath/add_file.rb';

  static String tempiOSAddFirebaseBuildPhaseScriptPath =
      '$tempiOSScriptsPath/add_firebase_build_phase.rb';

  static String tempiOSAddBuildConfigurationScriptPath =
      '$tempiOSScriptsPath/add_build_configuration.rb';

  static String ideaPath = '.idea';

  static String ideaLaunchpath = '$ideaPath/runConfigurations';

  static String vsCodePath = '.vscode';

  static String vsCodeLaunchPath = '$vsCodePath/launch.json';
}
