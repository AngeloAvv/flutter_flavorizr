// The entry point of flavorizr for this project. `dart run flutter_flavorizr`
// runs this file when it exists, so the command stays the same, and so does
// `dart run tool/flavorizr.dart`.

import 'package:flutter_flavorizr/flutter_flavorizr.dart';

import 'flavors_doc_processor.dart';

Future<void> main(List<String> args) =>
    Flavorizr.run(args, processors: const [FlavorsDocProcessor()]);
