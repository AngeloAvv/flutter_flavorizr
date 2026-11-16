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

import 'package:flutter_flavorizr/src/engine/shadow/shadow_workspace.dart';
import 'package:path/path.dart' as p;

/// A directory with convenient text file helpers, for tests.
class Tree {
  final Directory root;

  Tree(this.root);

  String abs(String relative) => p.joinAll([root.path, ...p.split(relative)]);

  void write(String relative, String content) {
    final file = File(abs(relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  String read(String relative) => File(abs(relative)).readAsStringSync();

  bool exists(String relative) =>
      FileSystemEntity.typeSync(abs(relative), followLinks: false) !=
      FileSystemEntityType.notFound;

  void delete(String relative) => File(abs(relative)).deleteSync();
}

/// A throwaway real project and the shadow workspaces made from it.
class ShadowFixture {
  final Directory scratch = Directory.systemTemp.createTempSync(
    'flavorizr_shadow_test_',
  );
  late final Tree project = Tree(
    Directory(p.join(scratch.path, 'project'))..createSync(),
  );
  final List<ShadowWorkspace> _created = [];

  /// Creates a shadow of [project] limited to [paths].
  Future<ShadowWorkspace> create(Iterable<String> paths) async {
    final shadow = await ShadowWorkspace.create(
      projectRoot: project.root,
      paths: paths,
    );

    return track(shadow);
  }

  ShadowWorkspace track(ShadowWorkspace shadow) {
    _created.add(shadow);

    return shadow;
  }

  Future<void> dispose() async {
    for (final shadow in _created) {
      await shadow.dispose();
    }

    scratch.deleteSync(recursive: true);
  }
}

extension ShadowTree on ShadowWorkspace {
  Tree get tree => Tree(root);

  String read(String relative) => tree.read(relative);

  void write(String relative, String content) => tree.write(relative, content);

  bool exists(String relative) => tree.exists(relative);

  void delete(String relative) => tree.delete(relative);
}
