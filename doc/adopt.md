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

## The first run without a lock

You do not have to run `adopt` first. When `plan`, `apply` or `status` find no
`flavorizr.lock` and the project has files flavorizr made before there was a
lock, they adopt the project themselves, in memory, and go on from there:

* `plan` and `status` write nothing, not even the lock. They say that the
  project was adopted, and show what 3.x would change against it, as after an
  `adopt`. `status` exits with `1` until the lock exists.
* `apply` shows the same plan. Once you approve it, it writes the changes and
  `flavorizr.lock`, with the baseline in it. If you do not approve it, nothing is
  written.

What tells that a project was flavorized by flavorizr before: `flavorizr.gradle(.kts)`
or the marked blocks of `build.gradle(.kts)`, of the CMake files of Linux and
Windows and of `my_application.cc`, and, for each flavor of `flavorizr.yaml`, its
xcconfigs (`<flavor>Debug.xcconfig`) and its launch storyboard. Only what is
specific to flavorizr counts: a project that was flavorized by hand has schemes,
`Debug-<flavor>` build configurations and app icon sets of its own, and its files
are yours, so a run asks about them as it always did. A project with none of the
files above is a new one, and its first run is the one it always was.

The baseline covers every processor of the default recipe, whatever the targets
of the run, so a first `apply android:icons` leaves the project ready for the run
of the rest. When one of them cannot read the project (a file it needs is
missing), only the processors of the run are adopted, and the run says so.

A lock that exists is never replaced by an adoption, whatever it records. A
project whose lock was lost is read the same way: the files that are there are
the baseline.

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

2.x copied dummy launcher icons and app icons for a flavor. 3.x does not make them: a flavor
with no icon uses the default icon of the project. `adopt` recognises them by
comparing each file with a table of the hashes of the dummy assets of 2.x:

* a file that still has the bytes 2.x wrote is **managed**: it is recorded, and
  since 3.x no longer makes it, the next `plan` proposes to delete it;
* a file that has other bytes is **yours**: it is not recorded, it is listed as
  such, and no run deletes or overwrites it.

This covers the Android icons (`android/app/src/<flavor>/res/mipmap-*`) and the
iOS and macOS app icons (`ios/Runner/Assets.xcassets/AppIcon-<flavor>.appiconset`
and the one of macOS). The launch images and storyboards of 2.x are not icons:
they are **yours**, as `ios:launchScreen` treats them. `adopt` lists them
(`ios/Runner/<flavor>LaunchScreen.storyboard` and
`ios/Runner/Assets.xcassets/<flavor>LaunchImage.imageset/`), records none, and no
run deletes them, not even when the flavor goes. The run that deletes the dummy
set of a flavor also points the flavor at the `AppIcon` of the project.

## The Xcode projects

`adopt` never rewrites `project.pbxproj`, and neither does a run rename an
object: the UUIDs that 2.x gave to its objects are the identity of them.
`adopt` records the UUIDs of the objects 2.x made, so that the next runs find
them again and remove them with their flavor:

* the build configurations `<Mode>-<flavor>` of the project and of its first
  target, and the references to the xcconfigs of the flavors;
* for the build settings flavorizr sets in those configurations, the value they
  have now, so that `plan` shows a change of one of them as a change, and never
  as a conflict.

The schemes and the xcconfig files of the flavors are recorded as the files they
are, so `plan` shows what 3.x would change in them, if anything. What 3.x would
create and the project does not have, such as an object with a UUID of its own,
is not recorded: `apply` makes it.

## Flavors that are not in `flavorizr.yaml` anymore

The flavors in `flavorizr.yaml` (and the ones of `--flavors`) are recorded in the
lock only when `adopt` covers every processor of the engine that a full run
covers. An `adopt` limited to targets, such as `adopt android:icons`, or one
whose default recipe leaves processors out, records the files of the processors
it ran and no flavor names, and says so. A flavor you removed from
`flavorizr.yaml` **before** the first run of 3.x cannot be detected: 2.x kept no record of
the flavors it applied, and nothing in the project says which files belong to a
flavor that is gone. Its files stay where they are, and flavorizr never deletes
a file it does not know.

When you know such a flavor, name it:

```sh
flutter pub run flutter_flavorizr adopt --flavors cherry,lemon
```

A name that `flavorizr.yaml` already has (case aside) is an error, with exit code
`64`: `--flavors` is for the flavors it no longer has. `adopt` then looks for the files 3.x would have made for them, like the dummy
icons and the xcconfigs, and records the ones that exist. The next `plan` shows
the flavors as removed, and the files as deleted. The settings of the flavors
are not known, so they are looked for as the settings of the flavors of
`flavorizr.yaml`, for each platform. That is enough to tell the name of a file,
not who owns it: the launcher icons and the app icons of such a flavor are recorded only when
they still have the bytes of the dummy icons of 2.x, whatever icon the flavors of
`flavorizr.yaml` have.
