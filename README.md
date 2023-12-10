# Flutter Flavorizr

A flutter utility to easily create flavors in your flutter application

[![Pub](https://img.shields.io/pub/v/flutter_flavorizr.svg)](https://pub.dev/packages/flutter_flavorizr)
![Dart CI](https://github.com/AngeloAvv/flutter_flavorizr/workflows/Dart%20CI/badge.svg)
[![Star on GitHub](https://img.shields.io/github/stars/AngeloAvv/flutter_flavorizr.svg?style=flat&logo=github&colorB=deeppink&label=stars)](https://github.com/AngeloAvv/flutter_flavorizr)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/AngeloAvv)

If you want to support this project, please leave a star, share this project, or consider donating through [Github Sponsor](https://github.com/sponsors/AngeloAvv).

## Getting Started

Let's start by setting up our environment in order to run Flutter
Flavorizr

### Prerequisites

Side note: this tool works better on a new and clean Flutter project.
Since some processors reference some existing files and a specific base
structure, it could be possible that running Flutter Flavorizr over an
existing project could throw errors.

Before running Flutter Flavorizr, you must install the following
software:

* [Ruby](https://www.ruby-lang.org/en/documentation/installation/)
* [Gem](https://rubygems.org/pages/download)
* [Xcodeproj](https://github.com/CocoaPods/Xcodeproj) (through RubyGems)

These prerequisites are needed to manipulate the iOS and macOS projects and
schemes. If you are interested in flavorizing Android only, you can skip
this step. Keep in mind that you will have to use a custom instructions
set with Android and Flutter processors only, otherwise an error will
occur.

### Installation

This package is intended to support development of Flutter projects. In
general, put it under
[dev_dependencies](https://dart.dev/tools/pub/dependencies#dev-dependencies),
in your [pubspec.yaml](https://dart.dev/tools/pub/pubspec):

```yaml
dev_dependencies:
  flutter_flavorizr: ^2.2.1
```

You can install packages from the command line:

```terminal
pub get
```

## Create your flavors

Once all of the prerequisites have been installed and you have added
flutter_flavorizr as a dev dependency, you have to edit your
[pubspec.yaml](https://dart.dev/tools/pub/pubspec) and define the
flavors.

### Example

Create a new file named flavorizr.yaml and define the name of the
flavors, in our example *apple* and *banana*. For each flavor you have
to specify the *app name*, the *applicationId* and the *bundleId*.

```yaml
flavors:
  apple:
    app:
      name: "Apple App"

    android:
      applicationId: "com.example.apple"  
    ios:
      bundleId: "com.example.apple"
    macos:
      bundleId: "com.example.apple"  
  banana:
    app:
      name: "Banana App"
  
    android:
      applicationId: "com.example.banana"
    ios:
      bundleId: "com.example.banana"
    macos:
      bundleId: "com.example.banana"
```

Alternatively, add a new key named flavorizr and define a sub item named *flavors*. 
Under the flavors array you can define the name of the
flavors, in our example *apple* and *banana*. For each flavor you have
to specify the *app name*, the *applicationId* and the *bundleId*.
This way of defining flavors will be deprecated in versions 3.x

```yaml
flavorizr:
  flavors:
    apple:
      app:
        name: "Apple App"

      android:
        applicationId: "com.example.apple"
      ios:
        bundleId: "com.example.apple"
      macos:
        bundleId: "com.example.apple"        
    banana:
      app:
        name: "Banana App"

      android:
        applicationId: "com.example.banana"
      ios:
        bundleId: "com.example.banana"
      macos:
        bundleId: "com.example.banana"
```

### Available fields

#### flavorizr

| key                                     | type   | default                                                                             | required | description                                                                                   |
|:----------------------------------------|:-------|:------------------------------------------------------------------------------------|:---------|:----------------------------------------------------------------------------------------------|
| app                                     | Object |                                                                                     | false    | An object describing the general capabilities of an app                                       |
| flavors                                 | Array  |                                                                                     | true     | An array of items. Each of them describes a flavor configuration                              |
| [instructions](#available-instructions) | Array  |                                                                                     | false    | An array of instructions to customize the flavorizr process                                   |
| assetsUrl                               | String | [link](https://github.com/AngeloAvv/flutter_flavorizr/releases/download/v2.2.1/assets.zip) | false    | A string containing the URL of the zip assets file. The default points to the current release |
| ide                                     | String |                                                                                     | false    | The IDE in which the app is being developed. Currently only `vscode` or `idea`                |

##### <a href="#available-instructions">Available instructions</a>

| value                   | category      | description                                                             |
|:------------------------|:--------------|:------------------------------------------------------------------------|
| assets:download         | Miscellaneous | Downloads the assets zip from the network                               |
| assets:extract          | Miscellaneous | Extracts the downloaded zip in the project .tmp directory               |
| assets:clean            | Miscellaneous | Removes the assets from the project directory                           |
| android:buildGradle     | Android       | Adds the flavors to the Android build.gradle file                       |
| android:androidManifest | Android       | Changes the reference of the app name in the AndroidManifest.xml        |
| android:dummyAssets     | Android       | Generates some default icons for your custom flavors                    |
| android:icons           | Android       | Creates a set of icons for each flavor according to the icon directive  |
| flutter:flavors         | Flutter       | Creates the flutter flavor configuration file                           |
| flutter:app             | Flutter       | Creates the app.dart entry                                              |
| flutter:pages           | Flutter       | Creates a set of default pages for the app                              |
| flutter:main            | Flutter       | Creates the main target to run the app                                  |
| flutter:targets         | Flutter       | Creates a set of targets for each flavor instance                       |
| google:firebase         | Google        | Adds Google Firebase configurations for Android and iOS for each flavor |
| huawei:agconnect        | Huawei        | Adds Huawei AGConnect configurations for Android for each flavor        |
| ide:config              | IDE           | Generates debugging configurations for each flavor of your IDE          |
| ios:xcconfig            | iOS           | Creates a set of xcconfig files for each flavor and build configuration |
| ios:buildTargets        | iOS           | Creates a set of build targets for each flavor and build configuration  |
| ios:schema              | iOS           | Creates a set of schemas for each flavor                                |
| ios:dummyAssets         | iOS           | Generates some default icons for your custom flavors                    |
| ios:icons               | iOS           | Creates a set of icons for each flavor according to the icon directive  |
| ios:plist               | iOS           | Updates the info.plist file                                             |
| ios:launchScreen        | iOS           | Creates a set of launchscreens for each flavor                          |
| macos:xcconfig          | macOS         | Creates a set of xcconfig files for each flavor and build configuration |
| macos:configs           | macOS         | Creates a set of xcconfig files for each flavor and build configuration |
| macos:buildTargets      | macOS         | Creates a set of build targets for each flavor and build configuration  |
| macos:schema            | macOS         | Creates a set of schemas for each flavor                                |
| macos:dummyAssets       | macOS         | Generates some default icons for your custom flavors                    |
| macos:icons             | macOS         | Creates a set of icons for each flavor according to the icon directive  |
| macos:plist             | macOS         | Updates the info.plist file                                             |

#### android (under app)

| key              | type   | default       | required | description                                                        |
|:-----------------|:-------|:--------------|:---------|:-------------------------------------------------------------------|
| flavorDimensions | String | "flavor-type" | false    | The value of the flavorDimensions in the android build.gradle file |
| resValues        | Array  | {}            | false    | An array which contains a set of resValues configurations          |
| buildConfigFields| Array  | {}            | false    | An array which contains a set of buildConfigFields configurations          |

#### ios (under app)

| key           | type       | default | required | description                                                                                    |
|:--------------|:-----------|:--------|:---------|:-----------------------------------------------------------------------------------------------|
| buildSettings | Dictionary | {}      | false    | An XCode build configuration dictionary [XCode Build Settings](https://xcodebuildsettings.com) |

#### macos (under app)

| key           | type       | default | required | description                                                                                    |
|:--------------|:-----------|:--------|:---------|:-----------------------------------------------------------------------------------------------|
| buildSettings | Dictionary | {}      | false    | An XCode build configuration dictionary [XCode Build Settings](https://xcodebuildsettings.com) |

#### app (under *flavorname*)

| key  | type   | default | required | description                   |
|:-----|:-------|:--------|:---------|:------------------------------|
| name | String |         | true     | The name of the App           |
| icon | String |         | false    | The icon path for this flavor |

#### android (under *flavorname*)

| key                 | type   | default | required | description                                                                |
|:--------------------|:-------|:--------|:---------|:---------------------------------------------------------------------------|
| applicationId       | String |         | true     | The applicationId of the Android App                                       |
| firebase            | Object |         | false    | An object which contains a Firebase configuration                          |
| resValues           | Array  |         | false    | An array which contains a set of resValues configurations                  |
| buildConfigFields   | Array  |         | false    | An array which contains a set of buildConfigFields configurations          |
| customConfig        | Array  |         | false    | An array which contains a set of custom configs, *overrides defaultConfig* |
| generateDummyAssets | bool   | true    | false    | True if you want to generate dummy assets (icon set, strings, etc)         |
| icon                | String |         | false    | The icon path for this android flavor                                      |
| adaptiveIcon        | Array  |         | false    | An array which contains foreground and background of adaptive icon         |

#### ios (under *flavorname*)

| key                 | type       | default | required | description                                                                                                   |
|:--------------------|:-----------|:--------|:---------|:--------------------------------------------------------------------------------------------------------------|
| bundleId            | String     |         | true     | The bundleId of the iOS App                                                                                   |
| buildSettings       | Dictionary | {}      | false    | A flavor-specific XCode build configuration dictionary [XCode Build Settings](https://xcodebuildsettings.com) |
| firebase            | Object     |         | false    | An object which contains a Firebase configuration                                                             |
| variables           | Array      |         | false    | An array which contains a set of variables configurations                                                     |
| generateDummyAssets | bool       | true    | false    | True if you want to generate dummy assets (xcassets, etc)                                                     |
| icon                | String     |         | false    | The icon path for this iOS flavor                                                                             |

#### macos (under *flavorname*)

| key                 | type       | default | required | description                                                                                                   |
|:--------------------|:-----------|:--------|:---------|:--------------------------------------------------------------------------------------------------------------|
| bundleId            | String     |         | true     | The bundleId of the macOS App                                                                                 |
| buildSettings       | Dictionary | {}      | false    | A flavor-specific XCode build configuration dictionary [XCode Build Settings](https://xcodebuildsettings.com) |
| firebase            | Object     |         | false    | An object which contains a Firebase configuration                                                             |
| variables           | Array      |         | false    | An array which contains a set of variables configurations                                                     |
| generateDummyAssets | bool       | true    | false    | True if you want to generate dummy assets (xcassets, etc)                                                     |
| icon                | String     |         | false    | The icon path for this macOS flavor                                                                           | 

#### firebase

| key    | type   | default | required | description                                                                                                                   |
|:-------|:-------|:--------|:---------|:------------------------------------------------------------------------------------------------------------------------------|
| config | String |         | false    | The path to the Firebase configuration file (google-services.json for Android and GoogleService-Info.plist for iOS and macOS) |

#### agconnect (for Android)

| key    | type   | default | required | description                                                            |
|:-------|:-------|:--------|:---------|:-----------------------------------------------------------------------|
| config | String |         | false    | The path to the AGConnect configuration file (agconnect-services.json) |

#### resValue (for Android)

| key   | type   | default | required | description                                                                                                                              |
|:------|:-------|:--------|:---------|:-----------------------------------------------------------------------------------------------------------------------------------------|
| type  | String |         | true     | The type of the [resValue](https://developer.android.com/reference/tools/gradle-api/7.0/com/android/build/api/variant/ResValue) variable |
| value | String |         | true     | The value of the resValue variable                                                                                                       |

```yaml
flavors:
  apple:
    app:
      name: "Apple App"
  
    android:
      applicationId: "com.example.apple"
      resValues:
        variable_one:
          type: "string"
          value: "example variable one"
        variable_two:
          type: "string"
          value: "example variable two"
  
    ios:
      bundleId: "com.example.apple"
```

#### buildConfigField (for Android)

| key   | type   | default | required | description                                                                                                                              |
|:------|:-------|:--------|:---------|:-----------------------------------------------------------------------------------------------------------------------------------------|
| type  | String |         | true     | The type of the [buildConfigField](https://developer.android.com/reference/tools/gradle-api/4.2/com/android/build/api/variant/BuildConfigField) variable |
| value | String |         | true     | The value of the buildConfigField variable                                                                                                       |

```yaml
flavors:
  apple:
    app:
      name: "Apple App"
  
    android:
      applicationId: "com.example.apple"
      buildConfigFields:
        field_one:
          type: "String"
          value: "example field one"
        field_two:
          type: "char"
          value: "y"
        field_three:
          type: "double"
          value: "20.0"
  
    ios:
      bundleId: "com.example.apple"
```

#### variable (for iOS and macOS)

| key    | type   | default | required | description                                                                                                                                                                                                                                          |
|:-------|:-------|:--------|:---------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| target | String |         | false    | The type of the [target](https://medium.com/geekculture/what-are-debug-and-release-modes-in-xcode-how-to-check-app-is-running-in-debug-mode-8dadad6a3428) (debug, release, profile). Do not specify a target if you want to apply it to all of them. |
| value  | String |         | true     | The value of the variable                                                                                                                                                                                                                            |

```yaml
flavors:
  apple:
    app:
      name: "Apple App"
  
    android:
      applicationId: "com.example.apple"
  
    ios:
      bundleId: "com.example.apple"
      variables:
        VARIABLE_ONE:
          value: "variable1"
        VARIABLE_TWO:
          target: "Debug"
          value: "variable2"        
```
#### customConfig (for Android only)

You can define any custom property for android
```yml
flavors:
  apple:
    app:
      name: "Apple App"
  
    android:
      applicationId: "com.example.apple"
      customConfig:
          versionNameSuffix: "\"-green-prod\"" # Don't forget to escape strings with \"
          signingConfig: flavorSigning.green
          versionCode: 1000
          minSdkVersion: 23
          # ..... and any custom property you want to add
```

This .yml part, generate this custom android flavor:

```groovy
apple {
  dimension "flavor-type"
  applicationId "com.example.apple"
  versionNameSuffix "-green-prod"
  signingConfig flavorSigning.green
  versionCode 1000
  minSdkVersion 23
}
```

#### adaptiveIcon (for Android only)

You can define adaptiveIcon for android:
```yml
flavors:
  apple:
    app:
      name: "Apple App"
  
    android:
      applicationId: "com.example.apple"
      icon: "assets/icon/appleApp/ic_launcher.png"
      adaptiveIcon:
        foreground: "assets/adaptive_icon/appleApp/ic_launcher_foreground.png"
        background: "assets/adaptive_icon/appleApp/ic_launcher_background.png"
```
After removing adaptiveIcon key, the adaptive icons generated before will still exist. Please delete adaptiveIcon manually.


## Usage

When you finished defining the flavorizr configuration, you can proceed by running the script with:

```terminal
flutter pub run flutter_flavorizr
```

You can also run flutter_flavorizr with a custom set of processors by appending the -p (or --processors) param followed by the processor names separated by comma:

```terminal
flutter pub run flutter_flavorizr -p <processor_1>,<processor_2>
```

Example

```terminal
flutter pub run flutter_flavorizr -p assets:download
flutter pub run flutter_flavorizr -p assets:download,assets:extract
```

## Run your flavors

Once the process has generated the flavors, you can run them by typing

```terminal
flutter run --flavor <flavorName> -t lib/main_<flavorName>.dart
```

Example

```terminal
flutter run --flavor apple -t lib/main_apple.dart
flutter run --flavor banana -t lib/main_banana.dart
```

Currently, due to a bug in the Flutter SDK, it's not possible to run the macOS flavors from the terminal.
You can run them from XCode by selecting the proper schema and by pressing play.

### Default processors set

By default, when you do not specify a custom set of processors by appending the -p (or --processors) param, a default processors set will be used:

* assets:download
* assets:extract
* android:androidManifest
* android:buildGradle
* android:dummyAssets
* android:icons
* flutter:flavors
* flutter:app
* flutter:pages
* flutter:main
* flutter:targets
* ios:xcconfig
* ios:buildTargets
* ios:schema
* ios:dummyAssets
* ios:icons
* ios:plist
* ios:launchScreen
* macos:xcconfig
* macos:configs
* macos:buildTargets
* macos:schema
* macos:dummyAssets
* macos:icons
* macos:plist
* google:firebase
* huawei:agconnect
* assets:clean
* ide:config

## Customize your app

Flutter_flavorizr creates different dart files in the lib folder. In the
flavors.dart file we have the F class which contains all of our
customizations.

```dart
class F {
  static Flavor? appFlavor;

  static String get title {
    switch (appFlavor) {
      case Flavor.APPLE:
        return 'Apple App';
      case Flavor.BANANA:
        return 'Banana App';
      default:
        return 'title';
    }
  }

}
```

The process creates a simple title customization: a
switch which checks the current appFlavor (defined in our app starting
point) and returns the correct value. Here you can write whatever you
want, you can create your custom app color palette, differentiate the
URL action of a button, and so on.

If you are wondering how to use these
getters, you can find an example under the pages folder: in the
my_home_page.dart file, the page shown after the launch of the app, we
can see a clear reference on the title getter defined in the F class.

## Side notes

I haven't found yet a good groovy parser to guarantee the idempotency of the AndroidBuildGradleProcessor.  
The only way to keep track of the autogenerated flavorDimensions is to mark up the beginning and the end of the section with magic comments.  
Please do not erase these comments otherwise you will break down the AndroidBuildGradleProcessor.

## Third party services

### Google Firebase

In order to flavorize your project and enable Firebase in your flavor you have to define a firebase object below each OS flavor. Under the firebase object you must define the config path of the google-services.json (if you are under Android configuration) or GoogleService-Info.plist (if you are under iOS or macOS configuration).

As you can see in the example below, we added the path accordingly

```yaml
flavors:
  apple:
    app:
      name: "Apple App"
  
    android:
      applicationId: "com.example.apple"
      firebase:
        config: ".firebase/apple/google-services.json"
  
    ios:
      bundleId: "com.example.apple"
      firebase:
        config: ".firebase/apple/GoogleService-Info.plist"
  
  banana:
    app:
      name: "Banana App"
      
    android:
      applicationId: "com.example.banana"
      firebase:
        config: ".firebase/banana/google-services.json"
    ios:
      bundleId: "com.example.banana"
      firebase:
        config: ".firebase/banana/GoogleService-Info.plist"
```

### Huawei AppGallery Connect

In order to flavorize your project and enable AppGallery Connect in your flavor  
you have to define an agconnect object below each Android flavor. Under the agconnect object you must define the config path of the agconnect-services.json.

As you can see in the example below, we added the path accordingly

```yaml
flavors:
  apple:
    app:
      name: "Apple App"
  
    android:
      applicationId: "com.example.apple"
      agconnect:
        config: ".agconnect/apple/agconnect-services.json"
  
    ios:
      bundleId: "com.example.apple"
  
  banana:
    app:
      name: "Banana App"
      
    android:
      applicationId: "com.example.banana"
      agconnect:
        config: ".agconnect/banana/agconnect-services.json"
    ios:
      bundleId: "com.example.banana"
```

## Troubleshooting
How to fix the error ["Unable to load contents of file list"](docs%2Ftroubleshooting%2Funable-to-load-contents-of-file-list%2FREADME.md)

## Docs & Tutorials (from the community)
[Easily build flavors in Flutter (Android and iOS) with flutter_flavorizr](https://angeloavv.medium.com/easily-build-flavors-in-flutter-android-and-ios-with-flutter-flavorizr-d48cbf956e4) - Angelo Cassano

[Get the best out of Flutter flavors with flutter_flavorizr](https://pierre-dev.hashnode.dev/get-the-best-out-of-flutter-flavors-with-flutterflavorizr) - Pierre Monier

## Further developments

* Let the user define its custom set of available instructions.

## Questions and bugs

Please feel free to submit new issues if you encounter problems while using this library.

If you need help with the use of the library or you just want to request new features, please use
the [Discussions](https://github.com/AngeloAvv/flutter_flavorizr/discussions) section of the 
repository. Issues opened as questions will be automatically closed.

## License

Flutter Flavorizr is available under the MIT license. See the LICENSE
file for more info.
