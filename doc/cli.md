# Command line

```sh
flutter pub run flutter_flavorizr [command] [options] [target...]
```

With no command, `apply` runs, so `flutter pub run flutter_flavorizr` keeps
doing what it always did. The command can be anywhere in the line, and every
command has `--help`.

| Command | What it does |
| --- | --- |
| `apply [target...]` | Shows what would change, asks, and applies it. Writes `flavorizr.lock`. |
| `plan [target...]` | The same preview, writing nothing: the processors that would run, with the ones they need marked `(auto)`, and the files that would be added (`+`), changed (`~`) or deleted (`-`), by platform. |
| `status [target...]` | Whether `flavorizr.yaml`, `flavorizr.lock` and the files agree. Exits with `1` on drift. |
| `list` | The recipes (built-in and the ones of `flavorizr.yaml`) and the processors, with what each needs. |
| `doctor` | Groovy or Kotlin build scripts, Xcode project layout, Pods, Flutter version, configuration and lock. |

`plan`, `apply`, `status` and `list` also take `--json`, which prints one JSON
document instead of text: see [the output](json-output.md).

A *target* is the name of a recipe (`android`, `all`, or one of yours) or the
id of a processor (`android:icons`). Without a target the default recipe runs:
the `instructions` of `flavorizr.yaml` when it has any, otherwise `default`
when it defines one, otherwise `all`.

## `apply` options

| Option | |
| --- | --- |
| `-y`, `--yes` | Does not ask for confirmation, which is what a CI wants. |
| `--on-conflict=keep\|overwrite` | What to do with a file edited by hand that the run would change. Without it a terminal asks for each file, and anything else fails. |
| `--overwrite-scaffold` | Also replaces the scaffold files that exist, which a run never does otherwise: all of them, `flavors.dart` included (see below). |
| `-v`, `--verbose` | Prints what every processor does (every command has it). |

## Output

On a terminal the commands show a spinner for each processor, grouped by
platform, a coloured diff of the files and a summary with the counts
(`+3 ~2 -0`) and the time. Anywhere else (a pipe, a file, a CI) the same words
are printed as plain lines: no colour, no animation, nothing is asked. `NO_COLOR`
removes the colour, and warnings and errors always go to stderr. With `--json`
stdout is one JSON document with a schema that is stable in 3.x. How the output
decides, and what the documents hold, is in [json-output.md](json-output.md).

## Deprecated options

The 2.x options still work, hidden from `--help`, and every use of them warns
(on stderr, so the output and the exit code of the run do not change). Both are
removed in **4.0**.

| Option | Use instead |
| --- | --- |
| `-f`, `--force` | `--yes` |
| `-p a,b,c`, `--processors a,b,c` | the targets after the command: `apply a b c` |

* `-p` and the targets can be mixed: the run is the sum of both. An empty `-p`
  (`-p ''`, a CI variable that is not set) runs what no `-p` runs, and warns.
* The 2.x assets pipeline is gone, since the assets ship with the package
  (#527): `assets:download`, `assets:extract` and `assets:clean` are skipped in
  `-p` with a warning, and the rest runs. When `-p` names nothing else, nothing
  runs (and not the default recipe), with exit code `0`.
* `-p list` is the target `list`, which does not exist, and not the `list`
  command: it exits with `64`.

So a 2.x CI command such as `flutter pub run flutter_flavorizr -f -p
assets:download,android:buildGradle` runs on 3.x with warnings only.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Everything went well. |
| `1` | Needs attention: files edited by hand are in the way (`plan`, `apply`), the project drifted (`status`), or a check failed (`doctor`). |
| `64` | The command line is wrong, e.g. an unknown target. |
| `65` | The configuration or `flavorizr.lock` cannot be used, or the configuration asks for what flavorizr cannot undo (see below). |
| `70` | A processor failed, or the project changed during the run. |

A run that fails does not write the engine's changes to the project, and the
lock is written last. A lock that cannot even be staged stops the run before
anything is written. There are three exceptions, and each says so:

* a copy-back that is interrupted lists what was and what was not written;
* a lock that cannot replace `flavorizr.lock` once the files are written exits
  with `70`: the engine's changes stay written, so fix what stops the lock from
  being written (permissions, a folder in its place) and run flavorizr again,
  which finds nothing to change and writes the lock;
* a 2.x processor that fails after the engine finished leaves the engine's
  changes in place.

## Removing flavors, and what flavorizr refuses

Removing flavors from `flavorizr.yaml` works, down to the last one: the files a
dropped flavor generated are deleted, and the lock follows.

`plan` and `apply` **refuse** two things, with exit code `65`, before any
processor runs, so nothing is written (not even the lock):

* removing **every** flavor, when `flavorizr.lock` records flavors;
* dropping a **platform** that `flavorizr.lock` shows was flavorized: no flavor
  has an `android` (`ios`, `macos`, ...) section anymore, and the lock records
  files of the processors of that platform. The message names the platform and
  lists the files the lock records for it.

The reason is that flavorizr overwrites the values it owns (`android:label` in
the manifest, `CFBundleName` in a plist) and does not store the originals, so it
cannot put them back. Fully un-flavorizing a project, or a platform, is out of
scope for 3.0. To do it, restore the files flavorizr changed from version
control (or put the original values back), delete the files it generated and
`flavorizr.lock`, and run flavorizr again with what remains in
`flavorizr.yaml`.

The check compares `flavorizr.yaml` with the lock only, whatever the targets,
and it only knows what the lock records (a lock that cannot be read fails it
with `65`, as it does a run of the engine): a project with no `flavorizr.lock`, or
a platform with no processor on the engine yet (which the lock cannot record),
is never refused. `status`, `list` and `doctor` do not run this check.

## `status` and drift

`status` runs the processors on a copy of the project, like `plan`, and exits
with `1` when any of these holds:

* there is no `flavorizr.lock`, when the selection holds processors of the
  engine: only a run of the engine writes the lock, so a selection with none
  (for example `status google:firebase`) has nothing to check, and says so;
* the flavors of `flavorizr.yaml` and of the lock differ (added, removed or
  changed);
* a file is not what `flavorizr.yaml` asks for, or is missing;
* a file generated by flavorizr was edited by hand.

What a user edits in a file flavorizr only patches (the manifest, `build.gradle`)
is not drift: only the part flavorizr owns is compared.

## The Flutter files

`flutter:flavors` writes two files in `lib`:

* `flavors.g.dart` holds the `Flavor` enum and `F`. It is **managed**: written
  whole from `flavorizr.yaml`, recorded in the lock, and a hand edit of it is a
  conflict. `F.appFlavor` reads the flavor from `appFlavor` of
  `package:flutter/services.dart` (what `--flavor` sets), by the name the flavor
  has in `flavorizr.yaml`, so nothing has to initialize it.
* `flavors.dart` exports `flavors.g.dart`. It is a **scaffold**: created when it
  does not exist and kept as it is by every ordinary run, so it is yours to
  extend. Only `--overwrite-scaffold` replaces it (see below). A project that
  flavorized with 2.x keeps the `flavors.dart` it has, which holds the enum: the
  run warns, and says to delete it and to remove the `F.appFlavor` assignment
  of its `main.dart`, which the generated `F` does not allow.

`flutter:app`, `flutter:pages` and `flutter:main` create `lib/app.dart`,
`lib/pages/my_home_page.dart` and `lib/main.dart`, the files of a new app. They
are scaffolds too, and they are **not** part of the `all` recipe: only the
`flutter:scaffold` recipe (or the processors by name) runs them, and any file
that already exists is left alone, so an ordinary `apply` never modifies the
`main.dart` of a project. The one of a project that was just created with
`flutter create` exists, though: run
`apply flutter:scaffold --overwrite-scaffold` to replace it, which previews the
change like any other (`plan` takes the flag too, to show it without applying).

> **Warning:** the flag replaces **every** scaffold file of the run that
> exists, not only the ones you named: `flutter:scaffold` pulls
> `flutter:flavors` in as a dependency, so `lib/flavors.dart` is replaced too,
> and so are an edited `app.dart` or page. `--yes` skips the confirmation. Use
> it on a fresh project, or commit first.

## The xcconfig files of the flavors

`ios:xcconfig`, `macos:xcconfig` and `macos:configs` write one `.xcconfig` for
each flavor and mode (`debug`, `profile`, `release`): `ios/Flutter`,
`macos/Flutter` and `macos/Runner/Configs`. They are generated files that
flavorizr owns, written as text, so `#include?` of the Pods xcconfig stays
optional (it does not exist until `pod install` ran), and a file you edit by
hand is reported as a conflict. The files of a flavor you remove from
`flavorizr.yaml` are deleted.

`ios:xcconfig` and `macos:configs` also add a reference to each file to
`Runner.xcodeproj`, where `ios:buildTargets` and `macos:buildTargets` use it as
the base configuration of the flavor. The files are **not** added to the
Resources build phase, which 2.x did and copied them into the app bundle: a
run takes the ones 2.x added out of it. The references of a flavor you remove
stay in the project, as the build configurations of the flavor do, until the 2.x
processors that own those are ported.

## Processors that are not on the engine yet

The engine runs the processors that were ported to it, which today are the
Android ones (`android:androidManifest`, `android:flavorizrGradle`,
`android:buildGradle` and `android:icons`), the Flutter ones
(`flutter:flavors`, `flutter:app`, `flutter:pages` and `flutter:main`) and the
xcconfig ones of Apple platforms (`ios:xcconfig`, `macos:xcconfig` and
`macos:configs`). For these a run is previewed, checked against the lock,
written atomically and recorded in `flavorizr.lock`.

Every other instruction (the other `ios:*` and `macos:*`, `linux:*`,
`windows:*`, `google:firebase`, `huawei:agconnect`, `ide:config`,
`android:dummyAssets` and the `assets:*` ones) still is a 2.x processor. They
are not dropped: `apply` runs them with the 2.x pipeline, **after** the engine,
straight on the project. That means they have no preview in `plan`, no conflict
detection, no lock entry and are not checked by `status`; the commands say so
every time they meet one, and `list` shows where each processor runs. When the
engine fails nothing else runs, and each port moves a processor from the 2.x
pipeline to the engine without any change to how you call flavorizr.

The 2.x processors never overwrite what the engine generated: the files the
engine writes whole (`flavorizr.gradle`, the launcher icons of `android:icons`)
are put back if a 2.x processor changes them. That is how
`android:dummyAssets`, which copies its whole folder over every flavor, keeps
the icons of the engine, as 2.x did by running `android:icons` last, and still
brings the rest of what the assets hold.

Known limits of the mix, which go away as processors are ported:

* The engine always runs first, so `android:icons` cannot run *after*
  `android:dummyAssets` as its `after` edge says. If a flavor got placeholders
  from an earlier 2.x run and you then give it an `icon`, the placeholders are
  files the lock does not know and the run reports them as conflicts: answer
  `--on-conflict=overwrite` once.
* `status` can only vouch for the processors of the engine. When some are not,
  it says `In sync, as far as the engine can tell` and lists the ones it did not
  check.
* `apply` asks `Do you want to proceed?` when stdin and stdout are a terminal,
  and goes on when there is not: nobody is asked, **even when an answer is piped
  to stdin**. In 2.x `echo n | flutter pub run flutter_flavorizr` could cancel;
  it now applies. Pass `--yes` in a CI and in any script to say so explicitly,
  `--on-conflict=keep|overwrite` for the files edited by hand, and use `plan` or
  `status` when nothing must be written.
