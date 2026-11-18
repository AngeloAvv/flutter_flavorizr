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
`flavorizr.yaml` are deleted. The name of a flavor is part of the name of its
files, so a run refuses (before it writes anything) a flavor that is empty, `.`
or `..`, or that has whitespace, a control or non-ASCII character, or any of
`" \ ; * /`: they cannot be told apart in `project.pbxproj`, and the project is
not read back as it was written when a name is not ASCII.

`ios:xcconfig` and `macos:configs` also add a reference to each file to
`Runner.xcodeproj`, where `ios:buildTargets` and `macos:buildTargets` use it as
the base configuration of the flavor. The files are **not** added to the
Resources build phase, which 2.x did and copied them into the app bundle: a
run takes the ones 2.x added out of every Resources phase of every target. The
rule is the name, not the configuration, so it also cleans the flavors that
`flavorizr.yaml` has not anymore: an entry is removed when it points at
`Flutter/<flavor>Debug.xcconfig` (iOS) or `Runner/Configs/<flavor>Debug.xcconfig`
(macOS), or the same with `Profile` or `Release`, whatever the `<flavor>`. The
other xcconfigs (`Flutter/Debug.xcconfig`, the ones of Pods, your own, anything
named otherwise, `debug` in lower case included) and the entries of the phases
that are not Resources are left alone.

The references have a UUID derived from their path, so two runs from scratch
write the same `project.pbxproj`, and the lock records them (`objects`). When
you remove a flavor, the references that flavorizr made for it are removed from
the project too, by UUID, with everything that pointed at them. A reference that
was there before flavorizr 3 (2.x made it, or you did) is used as it is and never
removed, because only the lock can tell it is not yours; neither are the build
configurations of the flavor until `ios:buildTargets` and `macos:buildTargets`
are ported, so they lose their base configuration when its reference goes.

## The Info.plist of the platforms

`ios:plist` and `macos:plist` edit `ios/Runner/Info.plist` and
`macos/Runner/Info.plist` in place. Only the value of a few `<string>` entries is
replaced in the text of the file: `CFBundleName` and `CFBundleDisplayName` on
iOS, `UILaunchStoryboardName` too when `ios:launchScreen` is one of the
instructions, and `CFBundleName` on macOS. 2.x parsed the plist and wrote it
back pretty printed, which reformatted the whole file: now indentation, line
endings, comments and the order of every other key are yours, and a plist that
is up to date is not written at all.

The lock records the owned keys, so editing one by hand is a conflict, while
anything else you change in the plist is not drift. `UILaunchStoryboardName` is
owned only while it has the value flavorizr gives it
(`$(ASSET_PREFIX)LaunchScreen`): with the launch screen off, the storyboard
Flutter wrote is yours. A plist without one of the keys, or whose value is not
a plain `<string>`, fails the run and writes nothing.

## Processors that are not on the engine yet

The engine runs the processors that were ported to it, which today are the
Android ones (`android:androidManifest`, `android:flavorizrGradle`,
`android:buildGradle` and `android:icons`), the Linux ones (`linux:cmake`,
`linux:runnerCmake` and `linux:myApplication`), the Windows ones that edit
files (`windows:mainCppTemplate`, `windows:runnerRcTemplate` and
`windows:cmake`), the Flutter ones (`flutter:flavors`, `flutter:app`,
`flutter:pages` and `flutter:main`), the xcconfig ones of Apple platforms
(`ios:xcconfig`, `macos:xcconfig` and `macos:configs`) and the `Info.plist`
ones (`ios:plist` and `macos:plist`). For these a run is
previewed, checked against the lock, written atomically and recorded in
`flavorizr.lock`.

The Linux processors patch files that belong to you, so they only ever touch the
regions between the `BEGIN`/`END ... (autogenerated by flutter_flavorizr)`
markers, which are the ones 2.x writes: everything else in `linux/CMakeLists.txt`,
`linux/runner/CMakeLists.txt` and `linux/runner/my_application.cc` is yours.
A flavor you drop from `flavorizr.yaml` is regenerated out of the regions on the
next run, as long as another flavor still has a `linux` section: dropping the
last one is refused (see *Removing flavors, and what flavorizr refuses*), so the
regions never keep a flavor that is gone. A call that sets the title has to be
a statement of its own, on a line of its own, with nothing but a comment that
ends on that line after it, and nothing governing it without braces (no `if`,
`else`, `for`, `while`, `do`, `case` or label right before it): the region goes
right after the call, and otherwise it would not do what the call does. When it
is not like that the run fails, before anything is written, and says what to
change. The variable `window_title`, when the setters read it, has to be declared
once as `const gchar* window_title = "...";`, and each way of setting the title
(`gtk_header_bar_set_title(header_bar, ...)`, `gtk_window_set_title(window, ...)`
or `gtk_window_set_title(GTK_WINDOW(window), ...)`) may be a literal call only
once. A call on another expression for the window (`self->window`, a variable
of another name) is not recognised: flavorizr does not count it, and it can
override the title of the flavor if it runs after. Comments, strings and
preprocessor directives are not looked at. When
`my_application.cc` sets the window title with two string
literals, as `flutter create` writes it, 2.x rewrote those two calls to use a
variable; 3.0 leaves them alone and sets the title again from regions right after
them.

The Windows processors no longer write into the source tree when you build.
`windows:mainCppTemplate` and `windows:runnerRcTemplate` make
`windows/runner/main.cpp.in` and `windows/runner/Runner.rc.in` from
`main.cpp` and `Runner.rc`, which they only read: the two templates are files
flavorizr owns (hashed in the lock, so a hand edit of them is a conflict), and
the two files they come from stay yours. `windows:cmake` only touches the region
of `windows/runner/CMakeLists.txt` between the same `BEGIN`/`END FLUTTER_APP_FLAVOR`
markers 2.x writes. The region sets the icon and the window title of the flavor
that is built (the defaults for a flavor that is not in `flavorizr.yaml`), makes
`Runner.rc` and `main.cpp` from the templates with `configure_file` **in the
build directory** (`${CMAKE_CURRENT_BINARY_DIR}`, not the source one, where 2.x
wrote them over your files and changed them at every flavored build) and points
the target at those copies. A flavor you drop from `flavorizr.yaml` is
regenerated out of the region on the next run, as long as another flavor still
has a `windows` section (dropping the last one is refused, as for Linux). A
project that 2.x flavorized is adopted: the templates are the ones 2.x wrote,
and 2.x put the region **before** `add_executable`, where the target does not
exist yet, so the one change to such a file that is not inside the region is
that the region moves after the call. A `Runner.rc` or `main.cpp` that a 2.x
build already rewrote (with the icon and the title of a flavor in it) is
templated all the same. The templates are regenerated at every `apply`, so run
it again after you change `main.cpp` or `Runner.rc`; `status` does not see a
change of the files they are made from. The icon of a flavor is still
`windows/runner/resources/<flavor>.ico`, which `windows:icons` and
`windows:dummyAssets` make.

The editors do not parse C++, CMake or resource scripts, and do not try to know
what is a comment, a string or a directive. They recognise a few **supported
shapes**, lines written the way `flutter create` writes them, and they count:
every mention of a token they act on, found by a plain search of the raw text
(comments, strings and raw strings included), has to be one of the supported
shapes. If there is any other, or none, the run fails, before anything is
written, with `found N mentions of X but only M in a position flavorizr
understands`. The price is that a file that mentions a token in a comment is
rejected too: remove the mention, or the comment.

*`windows/runner/CMakeLists.txt`* is read line by line, outside of the region.
Supported shapes: `add_executable(${BINARY_NAME} WIN32` alone on a line, the
sources on the lines after it with no parenthesis in them, a line with only `)`;
`main.cpp` and `Runner.rc` among the sources, each on a line of its own, as a
name (quoted or not) or after `${CMAKE_CURRENT_SOURCE_DIR}/`. Anything else that
mentions `add_executable` (also in a comment, or for another target), `main.cpp`
or `Runner.rc` (`./main.cpp`, `MAIN.CPP`, a later `target_sources`,
`set_property` or `set_target_properties`, a comment, a string; whole words, any
case, so `domain.cpp` is another file) is rejected, since a source that stays in
the target next to the copy of the binary directory defines `wWinMain` twice. So
are `[[` anywhere (bracket arguments and comments) and a line that ends with `\`.
A name that is in a variable is not seen. An old 2.x region before the call is
moved after it.

*`main.cpp`* supported shape: a line that starts with `window.Create(L"...", origin,
size)`, optionally after `if (!`, with a title without a quote or a backslash,
as many as you like, in any branch of an `#if`. Every mention of
`window . Create` (`.` or `->`) must be one of those. *`Runner.rc`* supported
shapes: `IDI_APP_ICON ICON "resources\\<name>"`, `VALUE "FileDescription", "..."
"\0"` and `VALUE "ProductName", "..." "\0"` lines, and every mention of
`IDI_APP_ICON`, `FileDescription` and `ProductName` must be one of those. In
both files: an `#include` that is not of a header (`.h`, `.hpp`, `.hh`, `.hxx`)
by a literal on a line of its own (`resource.h`, `winres.h` and the `TEXTINCLUDE`
string of the script are fine) is rejected, since the file it includes may hold
the tokens; so is a `\` at the end of a line, anywhere (it joins lines), and in
`main.cpp` the digraph `%:`. In all three files NUL, a form feed, a vertical tab
and a lone carriage return are rejected, and so is a file that is not UTF-8 (a
UTF-16 one that Visual Studio saved, for one). LF, CRLF or both are fine.
Trigraphs (`??/`) are not supported, because MSVC does not read them unless
`/Zc:trigraphs` is set, which Flutter does not do. A call that is written in
another way, such as `if (alt) window.Create(...); else window.Create(...);` on
one line, `bool ok = window.Create(...)`, or one with a macro for its title, is
rejected, and so are comments and strings that mention a token.

*Titles and flavor names.* The `app.name` of a flavor is encoded for each file
it ends up in, so `"`, `\` and non-ASCII characters are fine in it (in
`main.cpp` as `\"`, `\\` and universal character names; in `Runner.rc` as `""`
and `\\`, which needs `#pragma code_page(65001)` in `Runner.rc` when the title is
not ASCII, as `flutter create` writes it: the file must have exactly one mention
of `code_page`, which is that directive, or it is rejected; and then
for CMake, which also protects a `$`). A control character in it, such as a line
break, is rejected. A flavor name is the name of an icon file and goes into
CMake and `Runner.rc`, so it has to be made of letters, digits, `_`, `-` and
`.`, not end with a dot, and not be a name Windows reserves for a device
(`CON`, `PRN`, `AUX`, `NUL`, `COM1` to `COM9`, `LPT1` to `LPT9`, in any case and
with any extension).

Every other instruction (the other `ios:*` and `macos:*`,
`windows:dummyAssets`, `windows:icons`, `google:firebase`, `huawei:agconnect`, `ide:config`,
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
