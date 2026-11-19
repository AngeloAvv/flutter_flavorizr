# Flutter Flavorizr

A flutter utility to easily create flavors in your flutter application

[![Pub](https://img.shields.io/pub/v/flutter_flavorizr.svg)](https://pub.dev/packages/flutter_flavorizr)
[![Pipeline](https://github.com/AngeloAvv/flutter_flavorizr/actions/workflows/default.yml/badge.svg)](https://github.com/AngeloAvv/flutter_flavorizr/actions/workflows/default.yml)
[![codecov](https://codecov.io/gh/AngeloAvv/flutter_flavorizr/graph/badge.svg?token=D8V72QVK72)](https://codecov.io/gh/AngeloAvv/flutter_flavorizr)
[![Star on GitHub](https://img.shields.io/github/stars/AngeloAvv/flutter_flavorizr.svg?style=flat&logo=github&colorB=deeppink&label=stars)](https://github.com/AngeloAvv/flutter_flavorizr)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/AngeloAvv)

If you want to support this project, please leave a star, share this project, or consider donating through [Github Sponsor](https://github.com/sponsors/AngeloAvv).

## Getting Started

Let's start by setting up our environment in order to run Flutter Flavorizr

### Prerequisites

Side note: this tool works better on a new and clean Flutter project.
Since some processors reference some existing files and a specific base structure, it could be possible that running Flutter Flavorizr over an existing project could throw errors.

### Installation

This package is intended to support development of Flutter projects. In general, put it under [dev_dependencies](https://dart.dev/tools/pub/dependencies#dev-dependencies), in your [pubspec.yaml](https://dart.dev/tools/pub/pubspec):

```yaml
dev_dependencies:
  flutter_flavorizr: ^2.6.0
```

You can install packages from the command line:

```terminal
pub get
```

## Create your flavors

Once you have added flutter_flavorizr as a dev dependency, you have to edit your [pubspec.yaml](https://dart.dev/tools/pub/pubspec) and define the flavors.

### Example

Create a new file named flavorizr.yaml and define the name of the flavors, in our example *apple* and *banana*. For each flavor you have to specify the *app name*, the *applicationId* and the *bundleId*.

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
    linux:
      applicationId: "com.example.apple"
    windows: {}
  banana:
    app:
      name: "Banana App"
  
    android:
      applicationId: "com.example.banana"
    ios:
      bundleId: "com.example.banana"
    macos:
      bundleId: "com.example.banana"
    linux:
      applicationId: "com.example.banana"
    windows: {}
```

Alternatively, add a new key named flavorizr and define a sub item named *flavors*. 
Under the flavors array you can define the name of the flavors, in our example *apple* and *banana*. For each flavor you have to specify the *app name*, the *applicationId* and the *bundleId*.
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
      linux:
        applicationId: "com.example.apple"
      windows: {}
    banana:
      app:
        name: "Banana App"

      android:
        applicationId: "com.example.banana"
      ios:
        bundleId: "com.example.banana"
      macos:
        bundleId: "com.example.banana"
      linux:
        applicationId: "com.example.banana"
      windows: {}
```

### Available fields

#### flavorizr

| key                                     | type   | default                                                                                    | required | description                                                                                   |
|:----------------------------------------|:-------|:-------------------------------------------------------------------------------------------|:---------|:----------------------------------------------------------------------------------------------|
| app                                     | Object |                                                                                            | false    | An object describing the general capabilities of an app                                       |
| badge                                   | Bool   | false                                                                                      | false    | Turns on the [badge](#icon-badge) of every flavor, unless a flavor says otherwise |
| icon                                    | String |                                                                                            | false    | The source icon of the [badges](#icon-badge) when a flavor has no `icon` of its own           |
| flavors                                 | Array  |                                                                                            | true     | An array of items. Each of them describes a flavor configuration                              |
| recipes                                 | Map    |                                                                                            | false    | Named lists of [instructions](#available-instructions): `default` is what runs without a target |
| ide                                     | Array  |                                                                                            | false    | The IDE in which the app is being developed. Currently only `vscode` or `idea`                |

##### <a href="#available-instructions">Available instructions</a>

| value                   | category      | description                                                             |
|:------------------------|:--------------|:------------------------------------------------------------------------|
| android:flavorizrGradle | Android       | Adds the flavors to the Android flavorizr.gradle file                   |
| android:buildGradle     | Android       | Imports the Android flavorizr.gradle file into build.gradle file        |
| android:androidManifest | Android       | Changes the reference of the app name in the AndroidManifest.xml        |
| android:dummyAssets     | Android       | Does nothing now: a flavor with no `icon` uses the default icon         |
| android:icons           | Android       | Creates a set of icons for each flavor according to the icon directive  |
| flutter:flavors         | Flutter       | Generates lib/flavors.g.dart and, once, lib/flavors.dart               |
| flutter:app             | Flutter       | Creates lib/app.dart if it does not exist (`flutter:scaffold`)          |
| flutter:pages           | Flutter       | Creates a default page for the app if it does not exist (`flutter:scaffold`) |
| flutter:main            | Flutter       | Creates lib/main.dart if it does not exist (`flutter:scaffold`)         |
| google:firebase         | Google        | Adds Google Firebase configurations for Android and iOS for each flavor |
| huawei:agconnect        | Huawei        | Adds Huawei AGConnect configurations for Android for each flavor        |
| ide:config              | IDE           | Generates debugging configurations for each flavor of your IDE          |
| ios:podfile             | iOS           | Maps the build configurations of each flavor in the Podfile             |
| ios:xcconfig            | iOS           | Creates a set of xcconfig files for each flavor and build configuration |
| ios:buildTargets        | iOS           | Creates a set of build targets for each flavor and build configuration  |
| ios:schema              | iOS           | Creates a set of schemas for each flavor                                |
| ios:dummyAssets         | iOS           | Copies the launch image of each flavor (no dummy icons anymore)         |
| ios:icons               | iOS           | Creates a set of icons for each flavor according to the icon directive  |
| ios:plist               | iOS           | Sets the bundle name keys of Info.plist in place, keeping its format    |
| ios:launchScreen        | iOS           | Creates a set of launchscreens for each flavor                          |
| macos:podfile           | macOS         | Maps the build configurations of each flavor in the Podfile             |
| macos:xcconfig          | macOS         | Creates a set of xcconfig files for each flavor and build configuration |
| macos:configs           | macOS         | Creates a set of xcconfig files for each flavor and build configuration |
| macos:buildTargets      | macOS         | Creates a set of build targets for each flavor and build configuration  |
| macos:schema            | macOS         | Creates a set of schemas for each flavor                                |
| macos:dummyAssets       | macOS         | Does nothing now: a flavor with no `icon` uses the default `AppIcon`    |
| macos:icons             | macOS         | Creates a set of icons for each flavor according to the icon directive  |
| macos:plist             | macOS         | Sets the bundle name keys of Info.plist in place, keeping its format    |
| linux:cmake             | Linux         | Sets the application ID for each flavor in CMakeLists.txt               |
| linux:runnerCmake       | Linux         | Forwards FLUTTER_APP_FLAVOR into runner/CMakeLists.txt so it's available to native code |
| linux:myApplication     | Linux         | Sets the window title for each flavor in my_application.cc              |
| windows:mainCppTemplate | Windows       | Templates main.cpp into main.cpp.in so its window title can be set per flavor |
| windows:runnerRcTemplate| Windows       | Templates Runner.rc into Runner.rc.in so its icon/window title can be set per flavor |
| windows:cmake           | Windows       | Sets the icon/window title for each flavor in runner/CMakeLists.txt and builds the .in templates into the build directory with configure_file |
| windows:dummyAssets     | Windows       | Does nothing now: a flavor with no `icon` uses `app_icon.ico`           |
| windows:icons           | Windows       | Creates an icon for each flavor according to the icon directive          |

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
| includes      | Array      | []      | false    | A list of xcconfig files to include in every iOS flavor xcconfig                               |

#### macos (under app)

| key           | type       | default | required | description                                                                                    |
|:--------------|:-----------|:--------|:---------|:-----------------------------------------------------------------------------------------------|
| buildSettings | Dictionary | {}      | false    | An XCode build configuration dictionary [XCode Build Settings](https://xcodebuildsettings.com) |
| includes      | Array      | []      | false    | A list of xcconfig files to include in every macOS flavor xcconfig                             |

#### app (under *flavorname*)

| key  | type   | default | required | description                   |
|:-----|:-------|:--------|:---------|:------------------------------|
| name | String |         | true     | The name of the App           |
| icon | String |         | false    | The icon path for this flavor |

#### badge (under *flavorname*)

| key   | type   | default                  | required | description                                                                  |
|:------|:-------|:-------------------------|:---------|:-----------------------------------------------------------------------------|
| label | String | the flavor name, upper-cased | false | The text of the badge: 8 characters at most, a longer one is cut to 7 and `…` |
| color | String | from the palette, by the flavor name | false | The colour of the band, as `#RRGGBB`                                |

`badge` is `true`, `false`, or this map. See [Icon badge](#icon-badge).

#### android (under *flavorname*)

| key                 | type   | default | required | description                                                                |
|:--------------------|:-------|:--------|:---------|:---------------------------------------------------------------------------|
| applicationId       | String |         | true     | The applicationId of the Android App                                       |
| firebase            | Object |         | false    | An object which contains a Firebase configuration                          |
| resValues           | Array  |         | false    | An array which contains a set of resValues configurations                  |
| buildConfigFields   | Array  |         | false    | An array which contains a set of buildConfigFields configurations          |
| customConfig        | Array  |         | false    | An array which contains a set of custom configs, *overrides defaultConfig* |
| generateDummyAssets | bool   | true    | false    | **Deprecated and ignored** (see Icons): it will be an error in 4.0 |
| icon                | String |         | false    | The icon path for this android flavor                                      |
| adaptiveIcon        | Array  |         | false    | An array which contains foreground, background, monochrome (optional) of adaptive icon   |

#### ios (under *flavorname*)

| key                 | type       | default | required | description                                                                                                   |
|:--------------------|:-----------|:--------|:---------|:--------------------------------------------------------------------------------------------------------------|
| bundleId            | String     |         | true     | The bundleId of the iOS App                                                                                   |
| buildSettings       | Dictionary | {}      | false    | A flavor-specific XCode build configuration dictionary [XCode Build Settings](https://xcodebuildsettings.com) |
| firebase            | Object     |         | false    | An object which contains a Firebase configuration                                                             |
| variables           | Array      |         | false    | An array which contains a set of variables configurations                                                     |
| includes            | Array      | []      | false    | A list of xcconfig files to include in the generated xcconfig for this flavor                                 |
| generateDummyAssets | bool   | true    | false    | **Deprecated and ignored** (see Icons): it will be an error in 4.0 |
| icon                | String     |         | false    | The icon path for this iOS flavor                                                                             |

#### macos (under *flavorname*)

| key                 | type       | default | required | description                                                                                                   |
|:--------------------|:-----------|:--------|:---------|:--------------------------------------------------------------------------------------------------------------|
| bundleId            | String     |         | true     | The bundleId of the macOS App                                                                                 |
| buildSettings       | Dictionary | {}      | false    | A flavor-specific XCode build configuration dictionary [XCode Build Settings](https://xcodebuildsettings.com) |
| firebase            | Object     |         | false    | An object which contains a Firebase configuration                                                             |
| variables           | Array      |         | false    | An array which contains a set of variables configurations                                                     |
| includes            | Array      | []      | false    | A list of xcconfig files to include in the generated xcconfig for this flavor                                 |
| generateDummyAssets | bool   | true    | false    | **Deprecated and ignored** (see Icons): it will be an error in 4.0 |
| icon                | String     |         | false    | The icon path for this macOS flavor                                                                           | 

#### linux (under *flavorname*)

| key           | type   | default | required | description                                    |
|:--------------|:-------|:--------|:---------|:------------------------------------------------|
| applicationId | String |         | true     | The GTK application ID of the Linux App        |

#### windows (under *flavorname*)

| key                 | type   | default | required | description                                                         |
|:--------------------|:-------|:--------|:---------|:---------------------------------------------------------------------|
| generateDummyAssets | bool   | true    | false    | **Deprecated and ignored** (see Icons): it will be an error in 4.0 |
| icon                | String |         | false    | The icon path for this Windows flavor                                |

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

#### include (for iOS and macOS)

| key      | type   | default | required | description                                                                                                                                                                                                                                          |
|:---------|:-------|:--------|:---------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| value    | String |         | true     | The path of the xcconfig file to include                                                                                                                                                                                                             |
| target   | String |         | false    | The type of the [target](https://medium.com/geekculture/what-are-debug-and-release-modes-in-xcode-how-to-check-app-is-running-in-debug-mode-8dadad6a3428) (debug, release, profile). Do not specify a target if you want to apply it to all of them. |
| optional | bool   | false   | false    | If `true`, uses `#include?` — the build will not fail if the file is missing. Defaults to `false` (`#include`).                                                                                                                                      |

Global includes (under `app.ios` or `app.macos`) are merged with flavor-specific includes. Global entries come first; flavor entries are appended and take precedence for any duplicate keys.

```yaml
flavorizr:
  app:
    ios:
      includes:
        - value: "Shared/base.xcconfig"          # applied to all targets
        - value: "Shared/debug.xcconfig"
          target: debug                          # applied to debug only

  flavors:
    apple:
      app:
        name: "Apple App"

      android:
        applicationId: "com.example.apple"

      ios:
        bundleId: "com.example.apple"
        includes:
          - value: "Apple/flavor.xcconfig"
          - value: "Apple/optional.xcconfig"
            optional: true                       # → #include? "Apple/optional.xcconfig"
          - value: "Apple/release.xcconfig"
            target: release
```

#### Icons

A flavor with an `icon` (`app.icon`, or the `icon` of a platform) gets an icon
set of its own. **A flavor with no `icon` gets nothing generated, and builds with
the default icon of the project**: the `main` resources on Android,
`AppIcon` on iOS and macOS, `app_icon.ico` on Windows. An icon you put in the
project yourself (`src/<flavor>/res`, `AppIcon-<flavor>.appiconset`,
`<flavor>.ico`) is yours: flavorizr points the flavor at it and never deletes it.
`generateDummyAssets` is deprecated and ignored.

#### Icon badge

A badge is a band with the name of the flavor on its icon, to tell a `dev` build
from a `prod` one at a glance.

```yaml
badge: true                       # root default (default: false)
flavors:
  dev:
    app: { name: "App Dev" }
    badge: { label: DEV, color: "#E53935" }
  staging:
    app: { name: "App Staging" }  # inherits: label "STAGING", automatic colour
  prod:
    app: { name: "App" }
    badge: false                  # opt-out
```

* `badge: true` or a map turns it on for the flavor, `badge: false` off, and a
  flavor that says nothing does as the root `badge` does.
* `label` is the upper-cased name of the flavor by default. A label of more than
  8 characters is cut to 7 and `…`.
* `color` is picked from a palette by a stable hash of the name of the flavor,
  so it is the same in every run and on every machine. The text is black or
  white, whichever has the better contrast: at least 4.5:1 on every colour.
* There are no font or style options.
* The source icon of a badge is the first of these that is 512 px or more: the
  `icon` of the flavor, the `icon` of the root, the larger of the `AppIcon` of
  the iOS and the macOS project. When there is none, the run fails with a hint
  to set `icon:`. A flavor with a badge has icons made for it even when it has
  no `icon`.
* The band is across the bottom of the icon, with the label in the `arial48`
  bitmap font. It is drawn at each size of the icon, not scaled from a larger
  one, on the Android legacy mipmaps, the iOS and macOS icon sets and the
  Windows `.ico`. That font has no `…`: a label that was cut is drawn with `...`.
* On Android, the band of an adaptive icon is on its foreground, inside the
  safe zone (the 66 dp circle at the middle), so that no launcher mask cuts it.
  The background and the monochrome layer are left as they are.
* On Android only the icons made from a raster image are badged. A flavor
  without an `adaptiveIcon` of its own is **not** badged, and a warning says
  why, when `main` has `mipmap-anydpi-v26/ic_launcher.xml`: a device from
  Android 8 shows that adaptive icon (its foreground may be a vector) instead of
  the legacy mipmaps. Give the flavor a raster `adaptiveIcon`, or set
  `badge: false`.
* Changing the label or the colour makes the icons again on the next run, and
  `badge: false` makes the icons of the `icon` without it. The icons of the
  iOS, macOS and Windows flavors that have a badge and no `icon` stay in the
  project when the badge goes: they are those of the 2.x processors, which do
  not track what they write.

#### customConfig and manifestPlaceholders (for Android only)

Any property of the flavor in Gradle. Values are written in the language of the
script, Groovy or Kotlin, whichever your `build.gradle` is:

```yml
flavors:
  apple:
    app:
      name: "Apple App"

    android:
      applicationId: "com.example.apple"
      customConfig:
        versionNameSuffix: "-green-prod"     # text: quoted and escaped for you
        versionCode: 1000                    # numbers and booleans as they are
        resourceConfigurations: [en, it]     # a list: its items are added
        signingConfig: {raw: flavorSigning.green}   # code, written as it is
      manifestPlaceholders:
        appAuthRedirectScheme: com.example.apple
```

```kotlin
// build.gradle.kts
create("apple") {
    versionNameSuffix = "-green-prod"
    versionCode = 1000
    resourceConfigurations += listOf("en", "it")
    signingConfig = flavorSigning.green
    manifestPlaceholders["appAuthRedirectScheme"] = "com.example.apple"
}
```

```groovy
// build.gradle
apple {
    versionNameSuffix "-green-prod"
    versionCode 1000
    resourceConfigurations.addAll(["en", "it"])
    signingConfig flavorSigning.green
    manifestPlaceholders = ["appAuthRedirectScheme": "com.example.apple"]
}
```

* A text is always a string, so it needs no escaped quotes (2.x asked for
  `"\"-green-prod\""`: that is an error now). Code that is not a literal, such as
  `flavorSigning.green`, is `{raw: ...}`.
* A list adds its items to the property (`+=` in Kotlin, `addAll` in Groovy),
  which is what the collections of a flavor take: most cannot be assigned.
* `manifestPlaceholders` is a key of the flavor, not of `customConfig`, and
  works in both languages.

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
        monochrome: "assets/adaptive_icon/appleApp/ic_launcher_monochrome.png"
```

* monochrome (Themed icons on Android >= 13) is optional.
* After removing adaptiveIcon key, the adaptive icons generated before will still exist. Please delete adaptiveIcon manually.


## Usage

When you finished defining the flavorizr configuration, you can proceed by running the script with:

```terminal
flutter pub run flutter_flavorizr
```

You can also run flutter_flavorizr with a custom set of processors by appending the -p (or --processors) param followed by the processor names separated by comma. `-p` is deprecated and will be removed in 4.0: name the targets after the command instead (see [the command line](doc/cli.md)).

```terminal
flutter pub run flutter_flavorizr -p <processor_1>,<processor_2>
```

Example

```terminal
flutter pub run flutter_flavorizr apply android:buildGradle
flutter pub run flutter_flavorizr apply android:buildGradle android:icons
```

If you want to run flutter_flavorizr in verbose mode, you can append the -v (or --verbose) param:

```terminal
flutter pub run flutter_flavorizr -v
```

This will print all the logs to the console, including the ones from the processors.

If you want to skip the confirmation step, you can append the -y (or --yes) param. The 2.x -f (or --force) still works and does the same, with a warning, until 4.0:

```terminal
flutter pub run flutter_flavorizr --yes
```

### Commands

`flutter_flavorizr` has more commands than the one that applies the flavors. With no command, `apply` runs.

```terminal
flutter pub run flutter_flavorizr plan      # what would change, without writing anything
flutter pub run flutter_flavorizr apply     # plan, confirm, apply (the default)
flutter pub run flutter_flavorizr status    # does the project match flavorizr.yaml? Exits with 1 if not
flutter pub run flutter_flavorizr list      # recipes and processors
flutter pub run flutter_flavorizr doctor    # Groovy or Kotlin, Xcode project, Pods, Flutter version
```

Every command has `--help`, and every one ends with an exit code a CI can rely on. `plan`, `apply`, `status` and `list` take `--json` to print one JSON document instead of text, for CI, IDEs and agents ([schema and examples](doc/json-output.md)). See [doc/cli.md](doc/cli.md) for the options, the exit codes and the processors that do not run on the new engine yet.

## Run your flavors

Once the process has generated the flavors, you can run them by typing

```terminal
flutter run --flavor <flavorName>
```

Example

```terminal
flutter run --flavor apple
flutter run --flavor banana
```

Currently, due to a bug in the Flutter SDK, it's not possible to run the macOS flavors from the terminal.
You can run them from XCode by selecting the proper schema and by pressing play.

As a temporary workaround, you can apply the following configuration to your flavorizr config:

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
      buildSettings:
        LD_RUNPATH_SEARCH_PATHS:
          - "$(inherited)"
          - "@executable_path/../Frameworks"
```            

### Default processors set

By default, when you do not specify a custom set of processors by appending the -p (or --processors) param, a default processors set will be used:

* android:androidManifest
* android:flavorizrGradle
* android:buildGradle
* android:dummyAssets
* android:icons
* flutter:flavors
* ios:podfile
* ios:xcconfig
* ios:buildTargets
* ios:schema
* ios:dummyAssets
* ios:icons
* ios:plist
* ios:launchScreen
* macos:podfile
* macos:xcconfig
* macos:configs
* macos:buildTargets
* macos:schema
* macos:dummyAssets
* macos:icons
* macos:plist
* linux:cmake
* linux:runnerCmake
* linux:myApplication
* windows:mainCppTemplate
* windows:runnerRcTemplate
* windows:cmake
* windows:dummyAssets
* windows:icons
* google:firebase
* huawei:agconnect
* ide:config

## Customize your app

Flutter_flavorizr writes two files in the lib folder:

* `flavors.g.dart` holds the `Flavor` enum and the `F` class. It is generated from `flavorizr.yaml` and written again whenever the flavors change, so do not edit it.
* `flavors.dart` exports `flavors.g.dart`. It is created once and an ordinary run never overwrites it: it is yours, so this is the place to add your own code (a color palette per flavor, the URL of each environment, and so on).

> **Warning:** `--overwrite-scaffold` replaces `flavors.dart` (and every other scaffold file the run touches) with the stock one, and it does so also when you ask for `flutter:scaffold`, which pulls `flutter:flavors` in as a dependency. Commit your changes first, and look at the preview (`plan --overwrite-scaffold`) before you apply it.

```dart
class F {
  static Flavor get appFlavor { /* ... */ }

  static String get name => appFlavor.name;

  static String get title {
    switch (appFlavor) {
      case Flavor.apple:
        return 'Apple App';
      case Flavor.banana:
        return 'Banana App';
    }
  }
}
```

`F.appFlavor` reads the flavor the app was built with (`flutter run --flavor apple`) from `appFlavor` of `package:flutter/services.dart`, and finds it by the name the flavor has in `flavorizr.yaml`, casing included. Nothing has to initialize it. An app built without a flavor, or with one that is not in `flavorizr.yaml`, fails with an error that says how to fix it.

Flavorizr does not touch your `main.dart`, `app.dart` or `pages`. A new app can start from a ready made set of them with the `flutter:scaffold` recipe:

```sh
flutter pub run flutter_flavorizr apply flutter:scaffold
```

The recipe creates `lib/main.dart`, `lib/app.dart` and `lib/pages/my_home_page.dart`, which show how to use the getters above, and a file that exists is not overwritten. A new Flutter project already has a `lib/main.dart`: add `--overwrite-scaffold` to replace it. The flag replaces every scaffold file of the run that exists, `lib/flavors.dart` included (the recipe runs `flutter:flavors` as a dependency), so use it on a fresh project, not on one with code of yours in those files.

## Extending flavorizr

A project can register processors of its own, in `tool/flavorizr.dart`, and
replace the ones of flavorizr. See [Extending flavorizr](doc/extending.md) and
the [example](example).

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

After running flutter_flavorizr, remember to add the native dependencies for the targeted operative system. You can take advantage of [flutterfire_cli](https://firebase.google.com/docs/flutter/setup) to do so. Remember to ignore the generated firebase_options.dart file, as it will conflict with the flavors configuration. Do this instead:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Do not pass the options here
  
  runApp(const App());
}
```

### Huawei AppGallery Connect

In order to flavorize your project and enable AppGallery Connect in your flavor you have to define an agconnect object below each Android flavor. Under the agconnect object you must define the config path of the agconnect-services.json.

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

Remember to add the native dependencies for the targeted operative system for both Firebase and Huawei AppGallery Connect: flutter_flavorizr will only take care of applying the configuration.

## Troubleshooting
How to fix the error ["Unable to load contents of file list"](doc%2Ftroubleshooting%2Funable-to-load-contents-of-file-list%2FREADME.md)

How to fix [`appFlavor` being null when the app is launched from Xcode](doc/troubleshooting/app-flavor-null-from-xcode/README.md)

## Docs & Tutorials (from the community)
[Easily build flavors in Flutter (Android and iOS) with flutter_flavorizr](https://angeloavv.medium.com/easily-build-flavors-in-flutter-android-and-ios-with-flutter-flavorizr-d48cbf956e4) - Angelo Cassano

[Get the best out of Flutter flavors with flutter_flavorizr](https://pierre-dev.hashnode.dev/get-the-best-out-of-flutter-flavors-with-flutterflavorizr) - Pierre Monier

## Further developments

* Let the user define its custom set of available instructions.

## Questions and bugs

Please feel free to submit new issues if you encounter problems while using this library.

If you need help with the use of the library or you just want to request new features, please use the [Discussions](https://github.com/AngeloAvv/flutter_flavorizr/discussions) section of the repository. Issues opened as questions will be automatically closed.

## License

Flutter Flavorizr is available under the MIT license. See the LICENSE file for more info.
