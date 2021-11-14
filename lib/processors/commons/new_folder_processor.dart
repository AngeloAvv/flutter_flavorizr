import 'dart:io';

import 'package:flutter_flavorizr/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/processors/commons/abstract_processor.dart';

class NewFolderProcessor extends AbstractProcessor {
  final String path;
  late Directory dir;

  NewFolderProcessor(
    this.path, {
    required Flavorizr config,
  }) : super(config);

  @override
  execute() {
    this.dir = Directory(path);

    if (!this.dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  @override
  String toString() {
    return 'NewFolderProcessor: Creating directory $path';
  }
}
