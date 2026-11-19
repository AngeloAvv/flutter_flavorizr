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

/// The name of the recipe that runs everything.
const String allRecipeName = 'all';

/// The name of the recipe a run falls back to when no target is given and
/// the user did not choose one, provided the user defined a recipe with this
/// name.
const String defaultRecipeName = 'default';

/// The name of the recipe that scaffolds the starting files of a new app
/// (`main.dart`, `app.dart` and `pages/`), which no other recipe runs.
const String flutterScaffoldRecipeName = 'flutter:scaffold';

/// The platforms that have a recipe of their own, and whose processors are
/// skipped when the project has no flavors for them.
///
/// The name of a platform is the namespace of its processor ids
/// (`android:icons`) and the name of its built-in recipe.
const Set<String> platformRecipes = {
  'android',
  'ios',
  'macos',
  'linux',
  'windows',
};

/// The names of the commands, which cannot be used as recipe names.
const Set<String> reservedRecipeNames = {
  'init',
  'plan',
  'apply',
  'status',
  'list',
  'doctor',
  'adopt',
};

/// The recipes that ship with flavorizr, defined over processor ids and other
/// recipes.
///
/// A member that matches no available processor is ignored, so that a recipe
/// can name a processor before it exists.
const Map<String, List<String>> builtInRecipes = {
  allRecipeName: [
    'android',
    'flutter',
    'ios',
    'macos',
    'linux',
    'windows',
    'firebase',
    'huawei:agconnect',
    'ide',
  ],
  'android': [
    'android:androidManifest',
    'android:flavorizrGradle',
    'android:buildGradle',
    'android:dummyAssets',
    'android:icons',
  ],
  'ios': [
    'ios:podfile',
    'ios:xcconfig',
    'ios:buildTargets',
    'ios:schema',
    'ios:dummyAssets',
    'ios:icons',
    'ios:plist',
    'ios:launchScreen',
  ],
  'macos': [
    'macos:podfile',
    'macos:xcconfig',
    'macos:configs',
    'macos:buildTargets',
    'macos:schema',
    'macos:dummyAssets',
    'macos:icons',
    'macos:plist',
  ],
  'linux': ['linux:cmake', 'linux:runnerCmake', 'linux:myApplication'],
  'windows': [
    'windows:mainCppTemplate',
    'windows:runnerRcTemplate',
    'windows:cmake',
    'windows:dummyAssets',
    'windows:icons',
  ],
  'flutter': ['flutter:flavors'],
  // The starting files of a new app. They are not part of `all`: they are the
  // user's once they exist, and a project that has an app does not need them.
  flutterScaffoldRecipeName: ['flutter:app', 'flutter:pages', 'flutter:main'],
  'icons': ['android:icons', 'ios:icons', 'macos:icons', 'windows:icons'],
  'firebase': ['android:firebase', 'ios:firebase', 'macos:firebase'],
  // The one instruction of 2.x that was the three of them.
  'google:firebase': ['firebase'],
  'ide': ['ide:config'],
};
