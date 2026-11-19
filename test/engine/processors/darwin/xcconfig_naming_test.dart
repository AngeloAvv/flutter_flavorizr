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

import 'dart:io';

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/engine/darwin/owned_objects.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_naming.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_references.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_sources.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/enums.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../../../entrypoint/cli_fixture.dart';
import '../../darwin/pristine_project.dart';

/// The names of flavors, and whether flavorizr takes them: the one rule that the
/// guard of the processors, the cleanup of the Resources phases and the owned
/// content of the lock share.
const _names = <String, bool>{
  'apple': true,
  'myFlavor': true,
  'my-flavor': true,
  'my.flavor': true,
  'my_flavor': true,
  '1abc': true,
  'a\$b': true,
  "a'b": true,
  'a=b': true,
  'a{b}': true,
  'a#b': true,
  'a(b)': true,
  'a,b': true,
  'a<b>': true,
  'a&b': true,
  'a+b': true,
  'a@b': true,
  'a:b': true,
  'a[b]': true,
  'a|b': true,
  'a~b': true,
  'a%b': true,
  'a!b': true,
  'a?b': true,
  'a^b': true,
  'a`b': true,
  // `dart_xcodeproj` reads the project it wrote as UTF-8 back as Latin-1.
  'é': false,
  'ünï': false,
  '日本': false,
  'qa east': false,
  'qa\teast': false,
  'qa\neast': false,
  'qa east': false,
  ' apple': false,
  'apple ': false,
  'a"b': false,
  'a;b': false,
  'a*b': false,
  'a/b': false,
  r'a\b': false,
  'a\u0000b': false,
  'a\u0001b': false,
  'a\u007fb': false,
  '.': false,
  '..': false,
  '': false,
};

/// The UUID of the entry that puts [file] in the Resources phase.
String _entryOf(XcodeProject project, PBXFileReference file) => project
    .nativeTargets
    .first
    .resourcesBuildPhase
    .files
    .singleWhere((entry) => entry.fileRef == file)
    .uuid;

void main() {
  group('the name of a flavor', () {
    for (final MapEntry(key: name, value: valid) in _names.entries) {
      final shown = name.runes.any((rune) => rune < 0x20 || rune == 0x7f)
          ? name.codeUnits.toString()
          : '`$name`';

      test('$shown is ${valid ? 'taken' : 'refused'}', () {
        expect(isValidFlavorName(name), valid);
        expect(
          () => checkFlavorName(name),
          valid ? returnsNormally : throwsArgumentError,
        );
      });

      test('$shown is told the same by the file it makes', () {
        for (final target in Target.values) {
          final file = xcconfigName(name, target);

          for (final folder in ['Flutter', 'Runner/Configs']) {
            final matched = isFlavorXcconfigPath('$folder/$file');

            // The guard is stricter on `.` and `..` only, which make a file
            // that matches but that nobody asks for.
            if (valid) {
              expect(matched, isTrue, reason: '$folder/$file');
            } else if (name != '.' && name != '..') {
              expect(matched, isFalse, reason: '$folder/$file');
            }
          }
        }
      });
    }
  });

  group('the xcconfigs of a flavor, in a project that was saved', () {
    late Directory temp;
    late String bundle;

    FlavorizrContext context(XcodeProject project) => FlavorizrContext(
      config: FlavorizrConfig.parse(
        'flavors:\n  dev:\n    app:\n      name: dev\n'
        '    ios:\n      bundleId: com.example.dev\n',
      ),
      root: temp,
      projectRoot: temp,
      logger: RecordingLogger(),
      processorId: 'test:xcconfig',
      resources: {XcodeprojResource.iosKey: project},
    );

    String text() => File(p.join(bundle, 'project.pbxproj')).readAsStringSync();

    PBXFileReference reference(
      OwnedObjects owned,
      XcodeProject project,
      String path,
    ) {
      if (isFlavorXcconfigPath(path)) {
        return ensureXcconfigReference(owned, path, groupName: 'Flutter');
      }

      final file = project.newObject<PBXFileReference>(
        (g, u) => PBXFileReference(g, u),
      );

      file.path = path;
      file.sourceTree = '<group>';
      project.mainGroup.children.add(file);

      return file;
    }

    /// Saves the project with an entry in the Resources phase of its first
    /// target for each of [paths], and in another phase for each of
    /// [otherPhase].
    Future<void> save(
      Iterable<String> paths, {
      Iterable<String> otherPhase = const [],
    }) async {
      final project = await XcodeProject.open(bundle);
      final owned = OwnedObjects.ios(context(project));
      final target = project.nativeTargets.first;

      for (final path in paths) {
        target.resourcesBuildPhase.addFileReference(
          reference(owned, project, path),
        );
      }
      for (final path in otherPhase) {
        target
            .newCopyFilesBuildPhase('Copy')
            .addFileReference(reference(owned, project, path));
      }
      await project.save();
    }

    setUp(() async {
      temp = Directory.systemTemp.createTempSync('flavorizr_naming_');
      addTearDown(() => temp.deleteSync(recursive: true));
      bundle = p.join(temp.path, 'Runner.xcodeproj');
      Directory(bundle).createSync(recursive: true);
      // A project nobody flavorized, so that nothing but the test is in it.
      File(
        p.join(bundle, 'project.pbxproj'),
      ).writeAsStringSync(await pristineIosPbxproj(temp));
    });

    for (final MapEntry(key: name, value: valid) in _names.entries) {
      if (!valid) continue;

      test('of `$name` are cleaned and hashed, by the same rule', () async {
        final path = 'Flutter/${xcconfigName(name, Target.debug)}';
        await save([path]);

        final hashed = xcconfigReferencesOwnedContent(text());
        final project = await XcodeProject.open(bundle);
        final reference = project.files.singleWhere(
          (file) => file.path == path,
        );

        final entry = project.nativeTargets.first.resourcesBuildPhase.files
            .singleWhere((file) => file.fileRef == reference);

        // The reference, its entry in Resources and the listing of the entry.
        expect(
          hashed
              .split('\n')
              .where(
                (line) =>
                    line.contains(reference.uuid) || line.contains(entry.uuid),
              ),
          hasLength(3),
          reason: hashed,
        );

        removeXcconfigsFromResources(project);
        await project.save();

        expect(
          (await XcodeProject.open(bundle))
              .nativeTargets
              .first
              .resourcesBuildPhase
              .files
              .where((file) => file.fileRef == reference),
          isEmpty,
        );
      });
    }

    test('are hashed with the entries that put them in Resources, and only '
        'those', () async {
      await save(
        ['Flutter/appleDebug.xcconfig'],
        otherPhase: ['Flutter/bananaDebug.xcconfig'],
      );

      final hashed = xcconfigReferencesOwnedContent(text());
      final project = await XcodeProject.open(bundle);
      final apple = project.files.singleWhere(
        (file) => file.path == 'Flutter/appleDebug.xcconfig',
      );
      final banana = project.files.singleWhere(
        (file) => file.path == 'Flutter/bananaDebug.xcconfig',
      );
      final entry = project.nativeTargets.first.resourcesBuildPhase.files
          .singleWhere((file) => file.fileRef == apple);

      expect(
        hashed.split('\n').where((line) => line.contains(entry.uuid)),
        hasLength(2),
      );
      // An entry of another phase is not what the cleanup removes: not hashed.
      expect(hashed, contains(banana.uuid));
      expect(
        hashed.split('\n').where((line) => line.contains('PBXBuildFile')),
        hasLength(1),
      );
    });

    test('are not mistaken for an xcconfig that is not in the folder of '
        'flavorizr, whose entry has the same annotation', () async {
      await save([
        'Flutter/appleDebug.xcconfig',
        'Other/appleDebug.xcconfig',
        'Flutter/UserOverrides.xcconfig',
      ]);
      final before = xcconfigReferencesOwnedContent(text());
      final project = await XcodeProject.open(bundle);
      final other = project.files.singleWhere(
        (file) => file.path == 'Other/appleDebug.xcconfig',
      );

      // What is hashed is the flavor's (or the check would be about nothing).
      final apple = project.files.singleWhere(
        (file) => file.path == 'Flutter/appleDebug.xcconfig',
      );
      expect(before, contains(apple.uuid));
      expect(before, contains(_entryOf(project, apple)));

      // Not hashed: neither the reference nor the entry nor its listing.
      expect(before, isNot(contains(other.uuid)));
      expect(before, isNot(contains('Other/')));
      final entry = project.nativeTargets.first.resourcesBuildPhase.files
          .singleWhere((file) => file.fileRef == other);
      expect(before, isNot(contains(entry.uuid)));

      // So an edit of it, or taking it out of Resources, is not drift...
      final edited = text().replaceAll(
        'path = Other/appleDebug.xcconfig;',
        'path = Other/edited/appleDebug.xcconfig;',
      );
      expect(xcconfigReferencesOwnedContent(edited), before);
      final removed = text()
          .split('\n')
          .where((line) => !line.contains(entry.uuid))
          .join('\n');
      expect(xcconfigReferencesOwnedContent(removed), before);

      // ... and the cleanup leaves it where it is.
      removeXcconfigsFromResources(project);
      expect(
        project.nativeTargets.first.resourcesBuildPhase.files
            .map((file) => file.fileRef)
            .whereType<PBXFileReference>()
            .map((file) => file.path),
        containsAll([
          'Other/appleDebug.xcconfig',
          'Flutter/UserOverrides.xcconfig',
        ]),
      );
      expect(
        project.nativeTargets.first.resourcesBuildPhase.files
            .map((file) => file.fileRef)
            .whereType<PBXFileReference>()
            .map((file) => file.path),
        isNot(contains('Flutter/appleDebug.xcconfig')),
      );
    });
  });
}
