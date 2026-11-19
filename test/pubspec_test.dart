import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final manifest = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;

  Map<dynamic, dynamic> section(String name) =>
      (manifest[name] as YamlMap?) ?? YamlMap();

  group('pubspec.yaml', () {
    test('is a pure Dart package: no dependency on the Flutter SDK', () {
      for (final name in ['dependencies', 'dev_dependencies']) {
        final dependencies = section(name);

        expect(
          dependencies.keys.where(
            (key) => const {
              'flutter',
              'flutter_test',
              'flutter_lints',
            }.contains(key),
          ),
          isEmpty,
          reason: '$name must not list Flutter packages',
        );
        expect(
          dependencies.values.where(
            (value) => value is YamlMap && value['sdk'] == 'flutter',
          ),
          isEmpty,
          reason: '$name must not use the Flutter SDK',
        );
      }
    });

    test('tests and lints with package:test and package:lints', () {
      expect(section('dev_dependencies').keys, containsAll(['test', 'lints']));
    });

    test('declares the flavorizr executable', () {
      expect(manifest['executables'], {'flavorizr': 'flutter_flavorizr'});
    });

    test('keeps the SDK constraint', () {
      expect(section('environment')['sdk'], '>=3.9.0 <4.0.0');
    });
  });
}
