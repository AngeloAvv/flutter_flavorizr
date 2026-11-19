# example

A Flutter app flavorized with `flutter_flavorizr`: two flavors, `apple` and
`banana`, for every platform.

* [flavorizr.yaml](flavorizr.yaml) is the configuration.
* Everything flavorizr generated is committed, along with
  [flavorizr.lock](flavorizr.lock): the file that lets flavorizr remove what it
  generated and tell what was edited by hand.
* [tool/flavorizr.dart](tool/flavorizr.dart) is the entry point of the project,
  and [tool/flavors_doc_processor.dart](tool/flavors_doc_processor.dart) a
  small custom processor, which writes [FLAVORS.md](FLAVORS.md). See
  [Extending flavorizr](../doc/extending.md).

```sh
flutter pub get
dart run flutter_flavorizr status   # in sync with the lock?
dart run flutter_flavorizr plan     # what a run would change
dart run flutter_flavorizr          # apply

flutter run --flavor apple
```

`dart run flutter_flavorizr` runs `tool/flavorizr.dart`, since the project has
one: that is how its custom processor is part of the run. The pipeline of the
repository runs `status` here, so the example never drifts from what flavorizr
generates.
