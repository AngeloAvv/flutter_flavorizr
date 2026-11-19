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

import 'dart:convert';
import 'dart:io';

import 'package:flutter_flavorizr/experimental.dart';
import 'package:flutter_flavorizr/flutter_flavorizr.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:flutter_flavorizr/src/exception/duplicate_processor_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cli_fixture.dart';

/// A processor of the user: it declares the paths it works on itself.
class _SentryProcessor extends FlavorizrProcessor {
  const _SentryProcessor();

  @override
  String get id => 'acme:sentry';

  @override
  Set<String> get paths => const {'sentry.properties'};

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    const path = 'sentry.properties';

    ctx.track(const Artifact.managed(path));
    File('${ctx.root.path}/$path')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        [for (final name in ctx.config.flavors.keys) 'flavor=$name'].join('\n'),
      );
  }
}

/// Owns the line that starts with [key] of `shared.properties`.
class _SharedKey extends FlavorizrProcessor {
  @override
  final String id;

  final String key;

  const _SharedKey(this.id, this.key);

  @override
  Set<String> get paths => const {'shared.properties'};

  @override
  Map<String, String Function(String)> get ownedContent => {
    'shared.properties': (source) =>
        source.split('\n').where((line) => line.startsWith('$key=')).join('\n'),
  };

  @override
  Future<void> apply(FlavorizrContext ctx) async {}
}

/// Owns what it is told, whatever the file holds.
class _Fixed extends FlavorizrProcessor {
  @override
  final String id;

  final String part;

  const _Fixed(this.id, this.part);

  @override
  Map<String, String Function(String)> get ownedContent => {
    'fixed.txt': (_) => part,
  };

  @override
  Future<void> apply(FlavorizrContext ctx) async {}
}

class _Named extends FlavorizrProcessor {
  @override
  final String id;

  const _Named(this.id);

  @override
  Future<void> apply(FlavorizrContext ctx) async {}
}

void main() {
  late CliFixture project;

  setUp(() {
    project = CliFixture()
      ..registry = ProcessorRegistry.standard().withProcessors([
        const _SentryProcessor(),
      ]);
  });
  tearDown(() => project.dispose());

  group('a processor of the user', () {
    test('runs by its id, and what it writes is in the lock', () async {
      final code = await project.run(['apply', '--yes', 'acme:sentry']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read('sentry.properties'), 'flavor=apple\nflavor=banana');
      expect(project.read('flavorizr.lock'), contains('sentry.properties'));
    });

    test('is a member of a recipe of the configuration', () async {
      project.write(
        'flavorizr.yaml',
        '${CliFixture.config(['apple'])}'
            'recipes:\n  release:\n    - acme:sentry\n',
      );

      final code = await project.run(['apply', '--yes', 'release']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read('sentry.properties'), 'flavor=apple');
    });

    test('is listed', () async {
      await project.run(['list']);

      expect(project.logger.output, contains('acme:sentry'));
    });

    test('is not a member of the full run, which it does not change', () {
      expect(project.registry!.fullRunIds, isNot(contains('acme:sentry')));
    });
  });

  group('an id that no processor has', () {
    test('fails with a hint to register it in tool/flavorizr.dart', () async {
      final plain = CliFixture();
      addTearDown(plain.dispose);

      final code = await plain.run(['apply', '--yes', 'acme:sentry']);

      expect(code, ExitCodes.usage);
      expect(plain.logger.errors.join(), contains('tool/flavorizr.dart'));
    });
  });

  group('ProcessorRegistry.withProcessors', () {
    test('refuses an id that a processor of flavorizr has', () {
      expect(
        () => ProcessorRegistry.standard().withProcessors([
          const _Named('android:buildGradle'),
        ]),
        throwsA(
          isA<DuplicateProcessorException>().having(
            (e) => e.id,
            'id',
            'android:buildGradle',
          ),
        ),
      );
    });

    test('refuses an id that a legacy processor has', () {
      expect(
        () => ProcessorRegistry.standard().withProcessors([
          const _Named('huawei:agconnect'),
        ]),
        throwsA(isA<DuplicateProcessorException>()),
      );
    });

    test('refuses two processors with the same id', () {
      expect(
        () => ProcessorRegistry.standard().withProcessors([
          const _Named('acme:one'),
          const _Named('acme:one'),
        ]),
        throwsA(isA<DuplicateProcessorException>()),
      );
    });

    test(
      'reads each part of a file that processors own, when they share it',
      () {
        final registry = ProcessorRegistry.standard().withProcessors([
          const _SharedKey('acme:a', 'a'),
          const _SharedKey('acme:b', 'b'),
        ]);
        const artifact = Artifact.patched('shared.properties');

        List<int> file(String text) => utf8.encode(text);

        expect(
          registry.hash(artifact, file('a=1\nb=1\nc=1')),
          isNot(registry.hash(artifact, file('a=1\nb=2\nc=1'))),
        );
        expect(
          registry.hash(artifact, file('a=1\nb=1\nc=1')),
          isNot(registry.hash(artifact, file('a=2\nb=1\nc=1'))),
        );
        expect(
          registry.hash(artifact, file('a=1\nb=1\nc=1')),
          registry.hash(artifact, file('a=1\nb=1\nc=2')),
        );
      },
    );

    test('tells where the part of a processor ends and the next starts', () {
      ProcessorRegistry split(String a, String b) =>
          ProcessorRegistry.standard().withProcessors([
            _Fixed('acme:a', a),
            _Fixed('acme:b', b),
          ]);
      const artifact = Artifact.patched('fixed.txt');
      final bytes = utf8.encode('');

      expect(
        split('x\n', 'y').hash(artifact, bytes),
        isNot(split('x', '\ny').hash(artifact, bytes)),
      );
    });

    test('reads a lazy iterable of processors once', () {
      var reads = 0;
      final lazy = () sync* {
        reads++;
        yield const _Named('acme:one');
      }();

      final registry = ProcessorRegistry.standard().withProcessors(lazy);

      expect(registry.ids, contains('acme:one'));
      expect(reads, 1);
    });

    test('keeps the processors and the resources it had', () {
      final registry = ProcessorRegistry.standard();
      final extended = registry.withProcessors([const _SentryProcessor()]);

      expect(extended.engineIds, {...registry.engineIds, 'acme:sentry'});
      expect(extended.legacyIds, registry.legacyIds);
      expect(extended.resources, hasLength(registry.resources.length));
    });
  });
}
