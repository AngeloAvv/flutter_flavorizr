# Extending flavorizr

A project that needs a step flavorizr does not have writes a **processor** and
registers it in its own entry point. [`example/`](../example) does it: its
`tool/flavors_doc_processor.dart` writes `FLAVORS.md`, a table of the flavors.

## 1. The processor

```dart
import 'dart:io';

import 'package:flutter_flavorizr/experimental.dart';
import 'package:flutter_flavorizr/flutter_flavorizr.dart';

class FlavorsDocProcessor extends FlavorizrProcessor {
  const FlavorsDocProcessor();

  @override
  String get id => 'acme:flavorsDoc';

  @override
  Set<String> get paths => const {'FLAVORS.md'};

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final rows = [
      for (final MapEntry(key: name, value: flavor) in ctx.config.flavors.entries)
        '| `$name` | ${flavor.app.name} |',
    ];

    await File('${ctx.root.path}/FLAVORS.md').writeAsString(rows.join('\n'));
    ctx.track(const Artifact.managed('FLAVORS.md'));
  }
}
```

* `id` is namespaced and yours. The namespaces of flavorizr are reserved
  (`android`, `ios`, `macos`, `linux`, `windows`, `flutter`, `google`, `huawei`
  and `ide`).
* `paths` is what the processor reads or writes, relative to the project.
  Nothing outside of it is copied to the workspace of the run, diffed or
  written back.
* `apply` writes below `ctx.root`, the workspace of the run, never to the
  project; it reads the configuration from `ctx.config`; it says what it owns
  with `ctx.track`. The owner of a file decides what a run may do to it:
  `Artifact.managed` is written whole and hashed in the lock,
  `Artifact.patched` is a file the user also edits (declare what part is
  yours with `ownedContent`), `Artifact.scaffold` is created once and
  `Artifact.local` is regenerated and never hashed.
* `dependsOn` and `after` order the processor with the others, and `requires`
  names the shared resources it uses.

The processor files **must be pure Dart**: `tool/flavorizr.dart` runs with
`dart run`, not inside Flutter, so nothing it imports can import
`package:flutter` or `dart:ui`.

## 2. The entry point

```dart
// tool/flavorizr.dart
import 'package:flutter_flavorizr/flutter_flavorizr.dart';

import 'flavors_doc_processor.dart';

Future<void> main(List<String> args) =>
    Flavorizr.run(args, processors: const [FlavorsDocProcessor()]);
```

When the project has `tool/flavorizr.dart`, `dart run flutter_flavorizr` runs it
with the same arguments: the command stays a single one. See
[Your own processors](cli.md#your-own-processors) for how the delegation avoids
looping, and for `overrides`, which replace a processor of flavorizr.

## 3. The recipe

Processors that are not part of `all` run when something names them: a recipe
of `flavorizr.yaml`, or the command line (`flavorizr apply acme:flavorsDoc`).

```yaml
recipes:
  flavorized:
    - all
    - acme:flavorsDoc
  default: flavorized
```

`default` is the recipe `flavorizr` runs when it is given none.

## What a custom processor gets for free

* `plan` previews what it would write, and `apply` writes it atomically, with
  the same conflicts and `--on-conflict` as the processors of flavorizr.
* What it tracks is in `flavorizr.lock`: `status` reports it when it was edited
  or is out of date, and a flavor that is removed from `flavorizr.yaml` is
  cleaned up with the files of the other processors.
* `flavorizr list` shows it, with the processors it needs.

The pipeline of this repository checks that `example/` is in sync with its lock
(`flavorizr status`), custom processor included.
