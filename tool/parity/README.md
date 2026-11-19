# Golden parity harness

Safety net for the 3.0 rewrite (#494): it captures what flavorizr 2.6.0
produces on a fresh `flutter create` project, so that the ported processors can
be compared against it.

## How it works

1. `flutter create` makes a project for android, ios, macos, linux and windows
   in a temp dir and copies `fixtures/flavorizr.yaml` (two flavors, `apple` and
   `banana`, each with a Firebase configuration so that the build phase that
   gets a new random UUID on every run is exercised) plus `fixtures/files/`,
   which holds those placeholder Firebase configs. A checkout of 3.x gets
   `fixtures/flavorizr.3.yaml` instead: the same configuration in the words of
   3.x (`recipes` where 2.x had `instructions`), while the golden is recorded
   and identified by the 2.x one. A version from pub.dev is a 2.x reference and
   runs the 2.x fixture: check 3.x as a checkout.
2. The chosen flavorizr runs on it, `2.6.0` from pub.dev or a local checkout.
3. The result is normalized, so that two runs are identical:
   - every UUID of a `project.pbxproj` is rewritten from the object's
     structural path (the chain of fields and list indexes from `rootObject`)
     and the sections are sorted again;
   - timestamps become `<TIMESTAMP>`;
   - the `flutter_flavorizr` dependency in `pubspec.yaml` is dropped, as it
     tells where flavorizr comes from and not what it did;
   - binary files become `<file>.sha256`;
   - machine-dependent files are skipped (`ephemeral/`, `Generated.xcconfig`,
     `local.properties`, `pubspec.lock`, ...), and so are `.gitignore` files,
     which would otherwise hide part of the golden from git. See
     `defaultIgnore` in `src/tree.dart`.
4. `record` stores the result in `golden/<version>/tree`, `check` diffs a new
   run against it. pbxproj files are only compared, never built.

The golden is bound to the Flutter version in `golden/<version>/parity.json`
(the one pinned in `.fvmrc`): `check` refuses to compare with another one.

## Usage

```sh
# record the reference once (needs Flutter and the network)
dart run tool/parity.dart record --flavorizr 2.6.0 --golden tool/parity/golden/2.6.0

# check a flavorizr against it: a version, or the path of a checkout
dart run tool/parity.dart check --flavorizr . --golden tool/parity/golden/2.6.0
```

`check` exits with 1 if a file was added, removed or changed without a
whitelist entry.

## Intended differences

List them in `whitelist.yaml`. Each entry is a glob and a mandatory reason, so
that a difference never goes in unexplained.

```yaml
- path: android/app/src/main/res/**
  reason: M5 stops generating the dummy launcher assets (#527)
```

Whitelisted differences are still printed, with their reason.

An entry with `only-comments: true` covers a changed file only if it differs
from the golden in its `/* ... */` annotations and in nothing else, so that it
cannot hide a real change in a `project.pbxproj`:

```yaml
- path: ios/Runner.xcodeproj/project.pbxproj
  only-comments: true
  reason: dart_xcodeproj 0.4.0 annotates as Ruby's xcodeproj does (#513)
```

Two more options say what else a `project.pbxproj` may differ in. Both are
regular expressions, matched against **one line** of the file, and the file is
covered only if it is identical to the golden once they are applied (and, with
`only-comments`, once the annotations are stripped):

* `drop-from-golden` removes the lines of the golden that match, and names its
  UUIDs again, since the normalizer names a build file after its place in the
  list it is in and taking one out renames the ones after it. It is what the new
  output no longer has.
* `ignore` removes what matches from both files. It is what the new output has
  more of, in the lines it shares with the golden.
* `ignore-once` is a list of patterns that remove what matches from both files
  like `ignore`, but at most once in each: a file where one of them matches
  twice is not covered. It is for a block the new output has once, so that a
  copy of it is not taken for the intended one.

What they match is allowed to differ, so a pattern has to name exactly the thing
it vouches for: anchor it on the whole line, and say what the object is (a file
reference to a generated flavor xcconfig, not any xcconfig, and not any file that
happens to have the same attribute). `differ_test.dart` runs the entries of
`whitelist.yaml` as they ship, so a pattern that is too broad fails there.

```yaml
- path: ios/Runner.xcodeproj/project.pbxproj
  only-comments: true
  drop-from-golden: '^\s*\w{24} /\* Flutter/[^\s";*/\x00-\x1f\x7f-\uffff\\]+(?:Debug|Profile|Release)\.xcconfig in Resources \*/(?: = \{isa = PBXBuildFile; .*\};|,)$'
  ignore: '(?<=includeInIndex = 1; )lastKnownFileType = text\.xcconfig; (?=path = "?Flutter/[^\s";*/\x00-\x1f\x7f-\uffff\\]+(?:Debug|Profile|Release)\.xcconfig"?; )'
  reason: the generated xcconfigs are not resources, and have a type (#518)
```

## Tests

The unit tests run with `flutter test`. The end-to-end one, which flavorizes
a real project twice and expects identical output, is skipped by default:

```sh
flutter test --run-skipped -t parity
```
