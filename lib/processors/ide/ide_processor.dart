import 'package:flutter_flavorizr/parser/models/enums.dart';
import 'package:flutter_flavorizr/processors/commons/abstract_processor.dart';
import 'package:flutter_flavorizr/processors/commons/new_file_string_processor.dart';
import 'package:flutter_flavorizr/processors/commons/new_folder_processor.dart';
import 'package:flutter_flavorizr/processors/commons/queue_processor.dart';
import 'package:flutter_flavorizr/processors/ide/vscode_launch_processor.dart';
import 'package:flutter_flavorizr/utils/constants.dart';

class IDEProcessor extends AbstractProcessor {
  final IDE _ide;
  final Iterable<String> _flavors;

  AbstractProcessor _processor;

  IDEProcessor(this._ide, this._flavors);

  @override
  execute() {
    if (_ide != null) {
      switch (_ide) {
        case IDE.androidStudio:
          throw UnimplementedError();
          break;
        case IDE.vscode:
          _processor = QueueProcessor(
            [
              NewFolderProcessor(K.vsCodePath),
              NewFileStringProcessor(
                  K.vsCodeLaunchPath, VSCodeLaunchProcessor(_flavors.toList()))
            ],
          );
          break;
        default:
          break;
      }
    }

    if (_processor != null) {
      _processor.execute();
    }
  }

  @override
  String toString() {
    return 'IDEProcessor: ${_ide == null ? 'Skippping IDE file generation' : super.toString()}';
  }
}
