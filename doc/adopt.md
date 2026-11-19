# Adopting a project flavorized with 2.x

2.x left no `flavorizr.lock`, and it put no markers in most of what it wrote:
the Podfile, the `Info.plist`, the manifest and the project file are plain
files, and some of them were rewritten whole. Without a lock, 3.x cannot tell
what 2.x wrote from what you wrote, so a run would stop at every file as a
conflict.

`adopt` solves this without touching the project:

```sh
flutter pub run flutter_flavorizr adopt
flutter pub run flutter_flavorizr plan
```

`adopt` runs the processors on a copy of the project to learn which files 3.x
makes, and records the ones **your project already has** as they are now, as the
baseline in `flavorizr.lock`. It writes nothing else. `plan` then shows what 3.x
would change in each of them as an ordinary diff, which you review, and `apply`
writes it or not.

It fails when `flavorizr.lock` exists: the project has been run by 3.x already.

## What is recorded

For every file the processors of the default recipe (or of the `target`s you
give) make, and the project has:

* a file flavorizr generates whole (`flavors.dart`, `flavorizr.gradle(.kts)`, the
  xcconfigs of the flavors) is recorded with the hash of what is on disk;
* a file that is shared with you (the marked blocks of `build.gradle`, the keys
  of the manifest and of the `Info.plist`, the Podfile) is recorded with the
  hash of the part flavorizr owns.

A file the project does not have is not recorded: the next `apply` creates it.
The scaffold files (`lib/main.dart` and the like) are yours, and the run
configurations of the IDEs are regenerated silently: neither is recorded.

### The dummy icons

2.x copied dummy launcher icons for a flavor. 3.x does not make them: a flavor
with no icon uses the default icon of the project. `adopt` recognises them by
comparing each file with a table of the hashes of the dummy assets of 2.x:

* a file that still has the bytes 2.x wrote is **managed**: it is recorded, and
  since 3.x no longer makes it, the next `plan` proposes to delete it;
* a file that has other bytes is **yours**: it is not recorded, it is listed as
  such, and no run deletes or overwrites it.

Today this covers the Android icons (`android/app/src/<flavor>/res/mipmap-*`).
The iOS and macOS icons, the launch screens and the Xcode project are made by
2.x processors that are not on the engine yet: `adopt` lists them as not
adopted, and does not record them. The Xcode project is never rewritten, and
neither are its object identifiers.

## Flavors that are not in `flavorizr.yaml` anymore

The flavors in `flavorizr.yaml` are recorded in the lock. A flavor you removed
from it **before** the first run of 3.x cannot be detected: 2.x kept no record of
the flavors it applied, and nothing in the project says which files belong to a
flavor that is gone. Its files stay where they are, and flavorizr never deletes
a file it does not know.

When you know such a flavor, name it:

```sh
flutter pub run flutter_flavorizr adopt --flavors cherry,lemon
```

`adopt` then looks for the files 3.x would have made for them, like the dummy
icons and the xcconfigs, and records the ones that exist. The next `plan` shows
the flavors as removed, and the files as deleted. The settings of the flavors
are not known, so they are looked for as the settings of the flavors of
`flavorizr.yaml`, for each platform.
