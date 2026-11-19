# Flutter Flavorizr

Flavors for Flutter projects, declared in one file and kept in sync with the project: Android, iOS, macOS, Linux and Windows.

[![Pub](https://img.shields.io/pub/v/flutter_flavorizr.svg)](https://pub.dev/packages/flutter_flavorizr)
[![Pipeline](https://github.com/AngeloAvv/flutter_flavorizr/actions/workflows/default.yml/badge.svg)](https://github.com/AngeloAvv/flutter_flavorizr/actions/workflows/default.yml)
[![codecov](https://codecov.io/gh/AngeloAvv/flutter_flavorizr/graph/badge.svg?token=D8V72QVK72)](https://codecov.io/gh/AngeloAvv/flutter_flavorizr)
[![Star on GitHub](https://img.shields.io/github/stars/AngeloAvv/flutter_flavorizr.svg?style=flat&logo=github&colorB=deeppink&label=stars)](https://github.com/AngeloAvv/flutter_flavorizr)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/AngeloAvv)

Setting up flavors by hand means editing Gradle scripts, Xcode build configurations, schemes, plists, CMake
lists and icons, and doing it again for every flavor you add or drop. Describe the flavors in
`flavorizr.yaml` and flavorizr makes the project match: it shows what it would change, applies it
atomically, and removes what it generated when a flavor goes away.

If you want to support this project, please leave a star, share it, or consider donating through
[GitHub Sponsors](https://github.com/sponsors/AngeloAvv).

## Installation

```sh
flutter pub add --dev flutter_flavorizr
```

## Quickstart

```sh
dart run flutter_flavorizr init     # asks for the flavors, writes flavorizr.yaml
dart run flutter_flavorizr plan     # what would change, nothing is written
dart run flutter_flavorizr apply    # do it, and write flavorizr.lock
flutter run --flavor dev
```

Commit `flavorizr.lock` with the rest: it is how flavorizr knows what it generated.

## Features

- **Five platforms**: Android, iOS, macOS, Linux and Windows, and the Dart code that uses the flavors
- **Declarative**: the yaml is the desired state, `flavorizr.lock` the applied one, the disk is reality
- **Plan and apply**: dry runs, diffs and all-or-nothing writes, through a shadow copy of the project
- **Idempotent**: re-run it safely; what you edit in manifests, plists and Gradle scripts is left alone
- **Removes what it made**: drop a flavor from the yaml and its files and configurations go
- **Conflicts, not overwrites**: files you edited by hand are reported, and you choose what wins
- **Icons and badge**: per-flavor launcher icons, with an optional band that names the flavor
- **Recipes**: choose what runs, instead of a flat list of instructions
- **CI friendly**: `status` fails on drift, stable exit codes, `--json` on `plan`, `apply`, `status` and `list`
- **Extensible**: your own processors run in the same pipeline from `tool/flavorizr.dart`

## Documentation

The documentation is at **[docs.page/AngeloAvv/flutter_flavorizr](https://docs.page/AngeloAvv/flutter_flavorizr)**.

- [Getting started](https://docs.page/AngeloAvv/flutter_flavorizr/getting-started)
- [Core concepts](https://docs.page/AngeloAvv/flutter_flavorizr/concepts)
- [Configuration](https://docs.page/AngeloAvv/flutter_flavorizr/configuration)
- [Command line](https://docs.page/AngeloAvv/flutter_flavorizr/reference/cli)
- [Migrating from 2.x to 3.0](https://docs.page/AngeloAvv/flutter_flavorizr/migration)
- [Extending flavorizr](https://docs.page/AngeloAvv/flutter_flavorizr/extending/processors)
- [Troubleshooting](https://docs.page/AngeloAvv/flutter_flavorizr/troubleshooting)

The [example](example) is a Flutter app flavorized with flavorizr, with a custom processor.

## Community

- [Easily build flavors in Flutter (Android and iOS) with flutter_flavorizr](https://angeloavv.medium.com/easily-build-flavors-in-flutter-android-and-ios-with-flutter-flavorizr-d48cbf956e4) - Angelo Cassano
- [Get the best out of Flutter flavors with flutter_flavorizr](https://pierre-dev.hashnode.dev/get-the-best-out-of-flutter-flavors-with-flutterflavorizr) - Pierre Monier

## Questions and bugs

Please submit an [issue](https://github.com/AngeloAvv/flutter_flavorizr/issues) if you find a bug. For help
or feature requests use the [Discussions](https://github.com/AngeloAvv/flutter_flavorizr/discussions):
issues opened as questions are closed automatically.

## License

Flutter Flavorizr is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
