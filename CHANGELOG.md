## 3.0.0

### Breaking changes

Read the [migration guide](https://docs.page/AngeloAvv/flutter_flavorizr/migration) before you upgrade: following it on a project flavorized with 2.x ends with a clean `flavorizr status`.

* Removed the `instructions` key: `recipes` replaces it, and the recipe `default` is what runs without a target. The error prints the `recipes` to write
* Removed the `assetsUrl` key and the assets pipeline (`assets:download`, `assets:extract`, `assets:clean`): flavorizr bundles no assets and downloads nothing
* Deprecated and ignored `generateDummyAssets`, which becomes an error in 4.0. A flavor with no `icon` builds with the default icon of the project
* `customConfig` is typed: texts are quoted for you (a text with its own quotes is an error), code is written as `{raw: ...}`, and `manifestPlaceholders` is a key of the flavor
* Unknown keys of the configuration are errors, with their path, line and a suggestion
* `lib/flavors.dart` is split in `flavors.g.dart`, generated and managed, and `flavors.dart`, which exports it and is yours. `F.appFlavor` is read from Flutter and is not assigned anymore
* `apply` does not read an answer from a pipe anymore: pass `--yes` and `--on-conflict` in scripts
* `-f` (`--force`) and `-p` (`--processors`) are deprecated aliases of `--yes` and of the targets after the command, and are removed in 4.0
* Commit `flavorizr.lock`: it is how flavorizr removes what it generated and tells it from what you edited
* flutter_flavorizr is a pure Dart package: it does not depend on the Flutter SDK anymore and declares the `flavorizr` executable, so a custom entry point or a CI job needs only the Dart SDK
* The iOS launch screen is opt-in: `launchScreen: true` (at the root or in a flavor) makes `<flavor>LaunchScreen.storyboard` and `<flavor>LaunchImage.imageset` from the icon of the flavor, and `Info.plist` points at `$(LAUNCH_SCREEN_NAME)`, which each flavor defines in its xcconfig. The storyboards and launch images that 2.x copied are yours: they are never overwritten or deleted. This also fixes `UILaunchStoryboardName` being set only when `ios:launchScreen` was in the instructions that ran

### Features

* A new engine: runs are declarative and idempotent, go through a shadow workspace, and record what they generated in `flavorizr.lock`
* New commands: `init`, `plan`, `apply`, `status`, `list` and `doctor`, with exit codes and `--json` output for CI
* Removing a flavor from `flavorizr.yaml` removes it from the project
* Conflicts with files edited by hand are reported, and answered with `--on-conflict=keep|overwrite`
* Recipes, and custom processors registered in `tool/flavorizr.dart`
* Optional icon badge per flavor (`badge`, `icon`): a band with the name of the flavor, with a colour picked by a stable hash and a contrasting text, drawn at each size on the icons of Android, iOS, macOS and Windows
* Opt-in iOS launch screen per flavor (`launchScreen`), generated in code from the icon of the flavor, with its badge when it has one
* Adopting a project flavorized with 2.x: `flavorizr adopt` records what the project already has as the baseline of `flavorizr.lock` and writes nothing else, and the first `plan`, `apply` or `status` of a project that has no lock does the same in memory, so the first run shows what 3.0 changes and no conflicts. The placeholder icons of 2.x are recognised by their hash, and the UUIDs of the Xcode objects that 2.x made are recorded, not renamed
* The icons of Android, iOS and macOS are tracked in the lock: a flavor that loses its `icon` (and has no badge), or that is dropped, has its icons removed, and a flavor with no `icon` builds with the default icon of the project. The Windows icons are still made by a 2.x processor and stay when the flavor goes
* Build settings of the Xcode projects are edited key by key, so the `DEVELOPMENT_TEAM` chosen in Xcode is kept, and the objects of `project.pbxproj` have deterministic UUIDs: two runs from scratch write the same file
* The schemes of the iOS and macOS flavors are patched, not rewritten: flavorizr owns the file and the build configurations of its actions, and the pre-actions that Flutter adds, your arguments and your testables stay
* `Info.plist`, `AndroidManifest.xml`, the Podfile, the CMake lists and `launch.json` are edited in place, keeping their indentation, comments and everything flavorizr does not own
* The Firebase, IDE, Flutter, Linux, Windows, Podfile, `Info.plist`, xcconfig, build target, scheme, launch screen and icon processors run on the engine. Only `windows:icons`, `huawei:agconnect` and the `android:dummyAssets` and `windows:dummyAssets` that do nothing stay on the 2.x pipeline
* `init` writes `flavorizr.yaml`, and `tool/flavorizr.dart` runs a custom entry point, with processors of your own and explicit overrides of the built-in ones
* A stable library (`package:flutter_flavorizr/flutter_flavorizr.dart`), an experimental one (`package:flutter_flavorizr/experimental.dart`) and a read-only configuration model
* Typed `customConfig` and `manifestPlaceholders` for Groovy and Kotlin scripts, and a `flavorizr.gradle.kts` generated against `ApplicationExtension`
* A new documentation site on [docs.page](https://docs.page/AngeloAvv/flutter_flavorizr), including why `appFlavor` is `null` when a flavor is launched from Xcode, and a single example

## 2.6.0

* Added support for Linux platform (`linux:cmake`, `linux:runnerCmake`, `linux:myApplication` processors)
* Added support for Windows platform (`windows:cmake`, `windows:mainCppTemplate`, `windows:runnerRcTemplate`, `windows:dummyAssets`, `windows:icons` processors) — sets the per-flavor window title and app icon
* Generated flavor schemes now include testable references for unit-test and UI-testing targets
* Fixed generated Xcode schemes: added `BuildableProductRunnable` to `ProfileAction` and `MacroExpansion` to `TestAction`
* Fixed duplicate build configurations being created on native targets when re-running flavorizr on an already-configured project
* Bumped dependencies

## 2.5.0

* Replaced Ruby xcodeproj gem with dart_xcodeproj — no Ruby/gem installation required
* iOS/macOS app icon asset catalogs now use a `-<flavor>` suffix in their naming
* Added `includes` key to iOS and macOS xcconfig configuration (global under `app.ios`/`app.macos` and per-flavor) — supports optional per-target scoping and `#include?` via the `optional` flag

## 2.4.2

* Fixed incorrect LD_RUNPATH_SEARCH_PATHS for macOS build settings
* Fixed missing contents.json when generating darwin icons
* Added support for multiple ide values
* Bumped dependencies

## 2.4.1

* Fixed profile build configuration
* Updated supported platforms

## 2.4.0

* Updated logging system

## 2.3.1

* Fixed missing conditional Target Support Files include on MacOSXCConfigProcessor
* Support themed icon on Android >= 13
* Avoid new line at every run on build.gradle(.kts)
* Bumped dependencies

## 2.3.0

* Added support for Flutter 3.29.x
* Fixed "Xcodeproj is not installed" on Windows
* Fixed Android app name with single quotes
* Moved flavor dimensions to another file
* Removed flutter:targets processor and merged main_<flavor_name>.dart into main.dart
* Made F.appFlavor non-nullable
* Added support for both yml and yaml files
* Bumped dependencies

## 2.2.3

* Fixed add_firebase_build_phase script output paths
* Fixed "Unable to load contents of file list"

## 2.2.2

* Fixed misleading error message: The following fields were missing
* Fixed destination to macosDestination in FirebaseProcessor
* Fixed PathNotFoundException: Cannot open file, path = '.idea/runConfigurations/main_<flavorname>_dart.xml' (OS Error: No such file or directory, errno = 2)
* Fixed 'flavorDimensions' is deprecated
* Added support for generating android adaptive icons
* Added support for buildConfigFields
* Added XcodeprojProcessor to verify the existence of the xcodeproj gem
* Bumped dependencies

## 2.2.1

* Fixed platform optionals error due to eager processors initialization

## 2.2.0

* Added support to macOS
* Added common resValues for Android
* Changed the way flutter_flavorizr reads the instructions: from the flavorizr.yaml as a main source
  and pubspec.yaml as fallback
* main.dart generated more seamlessly
* BREAKING: Android and iOS definitions are no longer required: must remove definitions if they're unused

## 2.1.6

* Create file path if not existing when copying icon sets
* Set letters lowercase when created flavors
* Bumped dependencies
* Updated copyright version

## 2.1.5

* Json serializable build runner setup
* Bumped dependencies

## 2.1.4

* Added CFBundleDisplayName in Info.plist to show the proper name for iOS apps
* Bumped dependencies

## 2.1.3

* Added Android custom properties/config to flavors
* Relaxed first app entry checks
* New naming conventions for flutter_lints
* New README section: Docs and Tutorials
* Bumped dependencies

## 2.1.2

* Added resValues directive to declare resValues in build.gradle for each flavor (Android)
* Added variables directive to declare variables in xcconfig for each flavor (iOS)
* Bumped dependencies

## 2.1.1

* Added icon directive to generate icons for each flavor
* Bumped dependencies

## 2.1.0

* Added flavor banner in the top-left corner
* Disabled override of the launchScreen attribute in Info.plist if its processor is not specified
* Removed blank line generation at the end of the build.gradle file on every run
* Code refactoring
* Bumped dependencies

## 2.0.0

* Migration to Flutter 2

## 1.0.11

* Added FirebaseProcessor to plug Firebase configurations

## 1.0.10

* Added AndroidBuildGradleProcessor idempotency
* Bumped dependencies
* Updated LICENCE

## 1.0.9

* Fixed README

## 1.0.8

* Added buildConfig param in iOS configuration
* Added program argument in vscode configuration
* Added dash in iOS configuration

## 1.0.7

* Bumped dependencies

## 1.0.6

* Bumped dependencies

## 1.0.5

* Bumped dependencies

## 1.0.4

* Added processors param to the command line

## 1.0.3

* Added IDE processors (vscode and idea)
* Updated README

## 1.0.2

* Fixed zip asset extraction using sync
* Fixed zip asset creation with recursive param

## 1.0.1

* First release!
