# Golden parity harness

Safety net for the 3.0 rewrite (#494): it captures what flavorizr 2.6.0
produces on a fresh `flutter create` project, so that the ported processors can
be compared against it.

## How it works

1. `flutter create` makes a project for android, ios, macos, linux and windows
   in a temp dir and copies `fixtures/flavorizr.yaml` (two flavors, `apple` and
   `banana`).
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
     `local.properties`, `pubspec.lock`, ...). See `defaultIgnore` in
     `src/tree.dart`.
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

## Tests

The unit tests run with `flutter test`. The end-to-end one, which flavorizes
a real project twice and expects identical output, is skipped by default:

```sh
flutter test --run-skipped -t parity
```
