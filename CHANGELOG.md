## NEXT

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
