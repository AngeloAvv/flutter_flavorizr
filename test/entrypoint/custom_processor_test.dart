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
import 'package:flutter_flavorizr/src/exception/invalid_processor_registration_exception.dart';
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

/// Replaces a processor of flavorizr: it writes [source] to [path].
class _Replacement extends FlavorizrProcessor {
  @override
  final String id;

  final String path;
  final String source;

  const _Replacement(this.id, this.path, this.source);

  @override
  Set<String> get paths => {path};

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    ctx.track(Artifact.scaffold(path));
    File('${ctx.root.path}/$path')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(source);
  }
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

  group('a namespace of flavorizr', () {
    test('is refused to a new processor', () {
      for (final id in ['android:sentry', 'flutter:extra', 'ide:zed']) {
        expect(
          () => ProcessorRegistry.standard().withProcessors([_Named(id)]),
          throwsA(
            isA<InvalidProcessorRegistrationException>().having(
              (e) => e.toString(),
              'message',
              allOf(contains(id), contains('reserved'), contains('overrides')),
            ),
          ),
          reason: id,
        );
      }
    });

    test('is not refused to a namespace of the user, and any name without '
        'one', () {
      final registry = ProcessorRegistry.standard().withProcessors([
        const _Named('acme:one'),
        const _Named('mine'),
        const _Named('androidx:one'),
      ]);

      expect(registry.ids, containsAll(['acme:one', 'mine', 'androidx:one']));
    });

    test('is exit code 65', () {
      expect(
        ExitCodes.of(InvalidProcessorRegistrationException.reserved('ios:a')),
        ExitCodes.data,
      );
    });
  });

  group('overrides', () {
    ProcessorRegistry override(Iterable<FlavorizrProcessor> overrides) =>
        ProcessorRegistry.standard().withProcessors(
          const [],
          overrides: overrides,
        );

    test('a built-in id passed as a processor says to override it', () {
      expect(
        () => ProcessorRegistry.standard().withProcessors([
          const _Named('flutter:app'),
        ]),
        throwsA(
          isA<DuplicateProcessorException>().having(
            (e) => e.toString(),
            'message',
            contains('overrides'),
          ),
        ),
      );
    });

    test('replace the processor of flavorizr that has the id', () {
      const replacement = _Named('flutter:app');
      final registry = override([replacement]);

      expect(registry.engineProcessors['flutter:app'], same(replacement));
      expect(registry.overriddenIds, {'flutter:app'});
      expect(registry.ids, ProcessorRegistry.standard().ids);
    });

    test('work on the paths of the processor they replace too', () {
      final registry = override([
        const _Replacement('flutter:app', 'lib/mine.dart', ''),
      ]);

      expect(
        registry.pathsOf([registry.engineProcessors['flutter:app']!]),
        containsAll(['lib/app.dart', 'lib/mine.dart']),
      );
    });

    test('replace a processor that still runs on the legacy pipeline', () {
      final registry = override([const _Named('huawei:agconnect')]);

      expect(registry.isEngine('huawei:agconnect'), isTrue);
      expect(registry.legacyIds, isNot(contains('huawei:agconnect')));
      expect(registry.overriddenIds, {'huawei:agconnect'});
    });

    test('are refused when flavorizr has no processor with the id', () {
      expect(
        () => override([const _Named('acme:one')]),
        throwsA(
          isA<InvalidProcessorRegistrationException>().having(
            (e) => e.toString(),
            'message',
            contains('no processor'),
          ),
        ),
      );
    });

    test('are refused twice for the same id', () {
      expect(
        () => override([
          const _Named('flutter:app'),
          const _Named('flutter:app'),
        ]),
        throwsA(isA<DuplicateProcessorException>()),
      );
    });

    test('take the place of the processor in the recipes', () async {
      project.registry = override([
        const _Replacement('flutter:app', 'lib/app.dart', 'my app'),
      ]);

      final code = await project.run(['apply', '--yes', 'flutter:scaffold']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read('lib/app.dart'), 'my app');
      expect(project.exists('lib/main.dart'), isTrue);
    });

    test('are marked by list, as text and as json', () async {
      project.registry = override([const _Named('flutter:app')]);

      await project.run(['list']);

      expect(
        project.logger.lines,
        contains(startsWith('  flutter:app [engine] (overridden)')),
      );
      expect(
        project.logger.lines,
        contains(startsWith('  flutter:main [engine]\n')),
      );

      final json = CliFixture()..registry = project.registry;
      addTearDown(json.dispose);

      await json.run(['list', '--json']);

      final document = jsonDecode(json.stdout.toString()) as Map;
      final processors = (document['processors'] as List).cast<Map>();

      expect(
        processors.firstWhere((p) => p['id'] == 'flutter:app'),
        containsPair('overridden', true),
      );
      expect(
        processors.firstWhere((p) => p['id'] == 'flutter:main'),
        containsPair('overridden', false),
      );
    });
  });
}
