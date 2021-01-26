import 'dart:io';

import 'package:flutter_flavorizr/processors/commons/abstract_processor.dart';

class NewFolderProcessor extends AbstractProcessor {
  final String path;

  Directory? dir;

  NewFolderProcessor(this.path);

  @override
  execute() {
    dir = Directory(path);

    if (!dir!.existsSync()) {
      dir!.createSync(recursive: true);
    }
  }

  @override
  String toString() {
    return 'NewFolderProcessor: Creating directory $path';
  }
}
