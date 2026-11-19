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

import 'dart:isolate';

import 'package:flutter_flavorizr/src/engine/recipe/built_in_recipes.dart';
import 'package:flutter_flavorizr/src/engine/recipe/recipe_catalog.dart';
import 'package:flutter_flavorizr/src/exception/invalid_recipe_name_exception.dart';
import 'package:flutter_flavorizr/src/exception/recipe_cycle_exception.dart';
import 'package:flutter_flavorizr/src/exception/unknown_target_exception.dart';
import 'package:flutter_flavorizr/src/processors/processor.dart';
import 'package:test/test.dart';

/// What `all` runs: the default instruction set, which has no starting files
/// of a new app, with the Firebase processors of the engine where `google:firebase`
/// of 2.x was.
final _allIds = [
  for (final id in Processor.defaultInstructionSet) ...[
    if (id == 'huawei:agconnect') ...[
      'android:firebase',
      'ios:firebase',
      'macos:firebase',
    ],
    id,
  ],
];

/// The processor ids that exist today.
final _ids = [
  for (final id in _allIds) ...[
    id,
    if (id == 'flutter:flavors') ...[
      'flutter:app',
      'flutter:pages',
      'flutter:main',
    ],
  ],
];

RecipeCatalog _catalog({
  Map<String, List<String>> recipes = const {},
  String? defaultRecipe,
  Iterable<String>? processorIds,
}) => RecipeCatalog(
  processorIds: processorIds ?? _ids,
  recipes: recipes,
  defaultRecipe: defaultRecipe,
);

void main() {
  group('built-in recipes', () {
    test('a platform recipe expands to the processors of that platform', () {
      final resolution = _catalog().resolve(['linux']);

      expect(resolution.processorIds, [
        'linux:cmake',
        'linux:runnerCmake',
        'linux:myApplication',
      ]);
    });

    test('all expands to the legacy instruction set, in order, but for the '
        'files of a new app', () {
      final resolution = _catalog().resolve(['all']);

      expect(resolution.processorIds, _allIds);
    });

    test('cross-platform recipes group processors of several platforms', () {
      final catalog = _catalog();

      expect(catalog.resolve(['icons']).processorIds, [
        'android:icons',
        'ios:icons',
        'macos:icons',
        'windows:icons',
      ]);
      expect(catalog.resolve(['firebase']).processorIds, [
        'android:firebase',
        'ios:firebase',
        'macos:firebase',
      ]);
      // The 2.x instruction is the recipe of the three.
      expect(
        catalog.resolve(['google:firebase']).processorIds,
        catalog.resolve(['firebase']).processorIds,
      );
      expect(catalog.resolve(['ide']).processorIds, ['ide:config']);
      expect(catalog.resolve(['flutter']).processorIds, ['flutter:flavors']);
    });

    test('flutter:scaffold is the starting files of a new app, and only it '
        'runs them', () {
      final catalog = _catalog();

      expect(catalog.resolve(['flutter:scaffold']).processorIds, [
        'flutter:app',
        'flutter:pages',
        'flutter:main',
      ]);
      for (final name in ['all', 'flutter']) {
        expect(
          catalog.resolve([name]).processorIds,
          isNot(contains('flutter:main')),
          reason: name,
        );
      }
    });

    test(
      'every member of a built-in recipe is a known processor or recipe',
      () {
        for (final entry in builtInRecipes.entries) {
          for (final member in entry.value) {
            expect(
              _ids.contains(member) || builtInRecipes.containsKey(member),
              isTrue,
              reason: '${entry.key} names unknown member $member',
            );
          }
        }
      },
    );

    test('a member that matches no available processor is ignored', () {
      final catalog = _catalog(processorIds: ['linux:cmake']);

      expect(catalog.resolve(['linux']).processorIds, ['linux:cmake']);
    });
  });

  group('user recipes', () {
    test('may contain processor ids and built-in recipes', () {
      final catalog = _catalog(
        recipes: {
          'ci': ['linux', 'ios:plist'],
        },
      );

      expect(catalog.resolve(['ci']).processorIds, [
        'linux:cmake',
        'linux:runnerCmake',
        'linux:myApplication',
        'ios:plist',
      ]);
    });

    test('may contain other user recipes, however deeply nested', () {
      final catalog = _catalog(
        recipes: {
          'outer': ['middle', 'ide:config'],
          'middle': ['inner', 'ios:plist'],
          'inner': ['firebase'],
        },
      );

      expect(catalog.resolve(['outer']).processorIds, [
        'android:firebase',
        'ios:firebase',
        'macos:firebase',
        'ios:plist',
        'ide:config',
      ]);
    });

    test('a recipe used twice contributes its processors once', () {
      final catalog = _catalog(
        recipes: {
          'a': ['shared'],
          'b': ['shared', 'ide:config'],
          'shared': ['ios:plist'],
        },
      );

      expect(catalog.resolve(['a', 'b']).processorIds, [
        'ios:plist',
        'ide:config',
      ]);
    });

    test('a recipe that reaches itself is a cycle that names the path', () {
      expect(
        () => _catalog(
          recipes: {
            'a': ['b'],
            'b': ['c'],
            'c': ['a'],
          },
        ),
        throwsA(
          isA<RecipeCycleException>().having((e) => e.cycle, 'cycle', [
            'a',
            'b',
            'c',
            'a',
          ]),
        ),
      );
    });

    test('a recipe that contains itself is a cycle', () {
      expect(
        () => _catalog(
          recipes: {
            'a': ['a'],
          },
        ),
        throwsA(
          isA<RecipeCycleException>().having((e) => e.cycle, 'cycle', [
            'a',
            'a',
          ]),
        ),
      );
    });

    test('a cycle message lists the recipes along the path', () {
      expect(
        RecipeCycleException(['a', 'b', 'a']).toString(),
        contains('a -> b -> a'),
      );
    });

    test('a diamond is not a cycle', () {
      final catalog = _catalog(
        recipes: {
          'top': ['left', 'right'],
          'left': ['bottom'],
          'right': ['bottom'],
          'bottom': ['ide:config'],
        },
      );

      expect(catalog.resolve(['top']).processorIds, ['ide:config']);
    });
  });

  group('names', () {
    test('an unknown target fails with a did-you-mean suggestion', () {
      expect(
        () => _catalog().resolve(['androd']),
        throwsA(
          isA<UnknownTargetException>()
              .having((e) => e.name, 'name', 'androd')
              .having((e) => e.suggestion, 'suggestion', 'android'),
        ),
      );
    });

    test('a processor id typo suggests the processor', () {
      expect(
        () => _catalog().resolve(['android:buildGradel']),
        throwsA(
          isA<UnknownTargetException>().having(
            (e) => e.suggestion,
            'suggestion',
            'android:buildGradle',
          ),
        ),
      );
    });

    test('a user recipe is suggested too', () {
      final catalog = _catalog(
        recipes: {
          'staging': ['ios'],
        },
      );

      expect(
        () => catalog.resolve(['stagin']),
        throwsA(
          isA<UnknownTargetException>().having(
            (e) => e.suggestion,
            'suggestion',
            'staging',
          ),
        ),
      );
    });

    test('a name that resembles nothing has no suggestion', () {
      expect(
        () => _catalog().resolve(['completely-different']),
        throwsA(
          isA<UnknownTargetException>().having(
            (e) => e.suggestion,
            'suggestion',
            isNull,
          ),
        ),
      );
    });

    test('the message offers the suggestion', () {
      expect(
        UnknownTargetException('androd', suggestion: 'android').toString(),
        allOf(contains('"androd"'), contains('Did you mean "android"?')),
      );
    });

    test('nothing is resolved when any target is unknown', () {
      expect(
        () => _catalog().resolve(['ios', 'nope']),
        throwsA(isA<UnknownTargetException>()),
      );
    });

    test('an unknown member of a user recipe fails when building', () {
      expect(
        () => _catalog(
          recipes: {
            'ci': ['androd'],
          },
        ),
        throwsA(
          isA<UnknownTargetException>()
              .having((e) => e.recipe, 'recipe', 'ci')
              .having((e) => e.suggestion, 'suggestion', 'android'),
        ),
      );
    });

    test('an unknown default recipe fails when building', () {
      expect(
        () => _catalog(defaultRecipe: 'cii'),
        throwsA(isA<UnknownTargetException>()),
      );
    });

    test('a recipe cannot be named like a command', () {
      for (final name in [
        'init',
        'plan',
        'apply',
        'status',
        'list',
        'doctor',
        'adopt',
      ]) {
        expect(
          () => _catalog(
            recipes: {
              name: ['ios'],
            },
          ),
          throwsA(
            isA<InvalidRecipeNameException>().having(
              (e) => e.name,
              'name',
              name,
            ),
          ),
          reason: name,
        );
      }
    });

    test('a recipe cannot be named like a processor', () {
      expect(
        () => _catalog(
          recipes: {
            'ios:plist': ['ios'],
          },
        ),
        throwsA(isA<InvalidRecipeNameException>()),
      );
    });

    test('a recipe cannot be named like a built-in recipe', () {
      expect(
        () => _catalog(
          recipes: {
            'android': ['ios'],
          },
        ),
        throwsA(isA<InvalidRecipeNameException>()),
      );
    });

    test('a processor cannot be named like a built-in recipe', () {
      expect(
        () => _catalog(processorIds: [..._ids, 'android']),
        throwsA(
          isA<InvalidRecipeNameException>().having(
            (e) => e.name,
            'name',
            'android',
          ),
        ),
      );
    });

    test('a recipe name cannot be empty or use the processor namespace', () {
      for (final name in ['', '  ', 'android:mine', 'acme:ci']) {
        expect(
          () => _catalog(
            recipes: {
              name: ['ios'],
            },
          ),
          throwsA(isA<InvalidRecipeNameException>()),
          reason: '"$name"',
        );
      }
    });

    test('the message says why the name is rejected', () {
      expect(
        InvalidRecipeNameException('init', 'it is a command').toString(),
        allOf(contains('"init"'), contains('it is a command')),
      );
    });
  });

  group('recipes referenced many times', () {
    // r0 holds the leaf, and each next recipe lists the previous one twice:
    // expanding every reference would visit the leaf 2^29 times.
    final doubling = {
      'r0': ['android', 'ide:config'],
      for (var i = 1; i < 30; i++) 'r$i': ['r${i - 1}', 'r${i - 1}'],
    };

    // The work runs in another isolate: a test timeout cannot interrupt
    // synchronous code, but it can stop waiting for an isolate and fail.
    test('a recipe is expanded once, however often it is referenced', () async {
      final (ids, messages) = await Isolate.run(() {
        final resolution = _catalog(
          recipes: doubling,
        ).resolve(['r29'], platformsWithoutFlavors: {'android'});

        return (resolution.processorIds, resolution.messages);
      }).timeout(const Duration(seconds: 10));

      expect(ids, ['ide:config']);
      expect(messages, [
        'Skipping "android": no flavors are configured for android.',
      ]);
    });

    test('listing stays fast on the same graph', () async {
      final expansion = await Isolate.run(() {
        final listing = _catalog(recipes: doubling).listing();

        return listing.singleWhere((recipe) => recipe.name == 'r29').expansion;
      }).timeout(const Duration(seconds: 10));

      // The listing does not filter platforms: the leaf stands for the
      // android recipe, then ide:config.
      expect(expansion, [
        'android:androidManifest',
        'android:flavorizrGradle',
        'android:buildGradle',
        'android:dummyAssets',
        'android:icons',
        'ide:config',
      ]);
    });

    test('the first mention still decides the order', () {
      final catalog = _catalog(
        recipes: {
          'a': ['x', 'y'],
          'b': ['y', 'z'],
          'x': ['ios:plist'],
          'y': ['ide:config'],
          'z': ['ios:plist', 'linux:cmake'],
        },
      );

      expect(catalog.resolve(['b', 'a']).processorIds, [
        'ide:config',
        'ios:plist',
        'linux:cmake',
      ]);
    });
  });

  group('platforms without flavors', () {
    test('a platform recipe is skipped with an info message', () {
      final resolution = _catalog().resolve(
        ['android'],
        platformsWithoutFlavors: {'android'},
      );

      expect(resolution.processorIds, isEmpty);
      expect(resolution.messages, [
        'Skipping "android": no flavors are configured for android.',
      ]);
    });

    test('all keeps exactly what the legacy instruction filter keeps', () {
      for (final skipped in [
        <String>{},
        {'android'},
        {'ios', 'macos'},
        {'linux', 'windows'},
        {'android', 'ios', 'macos', 'linux', 'windows'},
      ]) {
        final resolution = _catalog().resolve([
          'all',
        ], platformsWithoutFlavors: skipped);

        expect(resolution.processorIds, [
          for (final id in _allIds)
            if (!skipped.contains(id.split(':').first)) id,
        ], reason: '$skipped');
      }
    });

    test('each skipped platform is reported once', () {
      final resolution = _catalog().resolve(
        ['all'],
        platformsWithoutFlavors: {'ios', 'linux'},
      );

      expect(resolution.messages, [
        'Skipping "ios": no flavors are configured for ios.',
        'Skipping "linux": no flavors are configured for linux.',
      ]);
    });

    test('a processor of a skipped platform is dropped from any recipe', () {
      final resolution = _catalog().resolve(
        ['icons'],
        platformsWithoutFlavors: {'ios', 'macos'},
      );

      expect(resolution.processorIds, ['android:icons', 'windows:icons']);
      expect(resolution.messages, [
        'Skipping "ios:icons": no flavors are configured for ios.',
        'Skipping "macos:icons": no flavors are configured for macos.',
      ]);
    });

    test('a processor requested by id is skipped like the legacy filter', () {
      final resolution = _catalog().resolve(
        ['ios:plist', 'ide:config'],
        platformsWithoutFlavors: {'ios'},
      );

      expect(resolution.processorIds, ['ide:config']);
      expect(resolution.messages, [
        'Skipping "ios:plist": no flavors are configured for ios.',
      ]);
    });

    test('a user recipe skips the platforms it names', () {
      final catalog = _catalog(
        recipes: {
          'ci': ['android', 'linux', 'acme:sentry'],
        },
        processorIds: [..._ids, 'acme:sentry'],
      );

      final resolution = catalog.resolve(
        ['ci'],
        platformsWithoutFlavors: {'android'},
      );

      expect(resolution.processorIds, [
        'linux:cmake',
        'linux:runnerCmake',
        'linux:myApplication',
        'acme:sentry',
      ]);
      expect(resolution.messages, [
        'Skipping "android": no flavors are configured for android.',
      ]);
    });

    test('nothing is skipped when every platform has flavors', () {
      final resolution = _catalog().resolve(['all']);

      expect(resolution.messages, isEmpty);
    });
  });

  group('listing', () {
    test('lists the built-in recipes first, then the user ones by name', () {
      final listing = _catalog(
        recipes: {
          'zeta': ['ide'],
          'alpha': ['ios:plist'],
        },
      ).listing();

      expect(listing.map((recipe) => recipe.name), [
        'all',
        'android',
        'ios',
        'macos',
        'linux',
        'windows',
        'flutter',
        'flutter:scaffold',
        'icons',
        'firebase',
        'google:firebase',
        'ide',
        'alpha',
        'zeta',
      ]);
      expect(listing.map((recipe) => recipe.builtIn), [
        ...List.filled(12, true),
        false,
        false,
      ]);
    });

    test('shows what a recipe contains and what it expands to', () {
      final listing = _catalog(
        recipes: {
          'ci': ['linux', 'inner', 'ios:plist'],
          'inner': ['ide'],
        },
      ).listing();

      final ci = listing.singleWhere((recipe) => recipe.name == 'ci');
      expect(ci.members, ['linux', 'inner', 'ios:plist']);
      expect(ci.expansion, [
        'linux:cmake',
        'linux:runnerCmake',
        'linux:myApplication',
        'ide:config',
        'ios:plist',
      ]);
    });

    test('hands out lists that cannot change the catalog', () {
      final catalog = _catalog();

      for (final recipe in catalog.listing()) {
        expect(() => recipe.members.add('x'), throwsUnsupportedError);
        expect(() => recipe.expansion.add('x'), throwsUnsupportedError);
      }
      expect(catalog.resolve(['all']).processorIds, _allIds);
    });

    test('marks the recipe that runs without a target', () {
      expect(
        _catalog()
            .listing()
            .where((recipe) => recipe.isDefault)
            .map((recipe) => recipe.name),
        ['all'],
      );
      expect(
        _catalog(
              recipes: {
                'ci': ['ios'],
              },
              defaultRecipe: 'ci',
            )
            .listing()
            .where((recipe) => recipe.isDefault)
            .map((recipe) => recipe.name),
        ['ci'],
      );
    });

    test('renders the recipes as text', () {
      final text = _catalog(
        recipes: {
          'ci': ['linux', 'ios:plist'],
          'none': [],
        },
        defaultRecipe: 'ci',
        processorIds: ['linux:cmake', 'ios:plist', 'ide:config'],
      ).renderListing();

      expect(
        text,
        contains('''
ci (default)
  contains: linux, ios:plist
  expands to: linux:cmake, ios:plist
'''),
      );
      expect(
        text,
        contains('''
ide (built-in)
  contains: ide:config
'''),
      );
      expect(
        text,
        contains('''
none
  contains: nothing
'''),
      );
    });
  });

  group('targets', () {
    test('a processor id is a target of its own', () {
      final resolution = _catalog().resolve(['ios:plist']);

      expect(resolution.processorIds, ['ios:plist']);
    });

    test('targets are merged without duplicates, first mention wins', () {
      final resolution = _catalog().resolve(['ios:plist', 'icons', 'ios']);

      expect(resolution.processorIds.where((id) => id == 'ios:plist'), [
        'ios:plist',
      ]);
      expect(resolution.processorIds.first, 'ios:plist');
      expect(
        resolution.processorIds.toSet().length,
        resolution.processorIds.length,
      );
    });

    test('no target runs all', () {
      final resolution = _catalog().resolve([]);

      expect(resolution.processorIds, _allIds);
    });

    test('no target runs the default recipe when the user defines one', () {
      final catalog = _catalog(
        recipes: {
          'default': ['linux'],
        },
      );

      expect(catalog.resolve([]).processorIds, [
        'linux:cmake',
        'linux:runnerCmake',
        'linux:myApplication',
      ]);
    });

    test('no target runs the recipe named as default', () {
      final catalog = _catalog(
        recipes: {
          'ci': ['ios:plist'],
        },
        defaultRecipe: 'ci',
      );

      expect(catalog.resolve([]).processorIds, ['ios:plist']);
    });
  });
}
