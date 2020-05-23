import 'package:flutter_flavorizr/parser/models/enums.dart';
import 'package:flutter_flavorizr/processors/commons/abstract_processor.dart';
import 'package:flutter_flavorizr/processors/ide/idea/idea_run_configurations_processor.dart';
import 'package:flutter_flavorizr/processors/ide/vscode/vscode_launch_file_processor.dart';
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
        case IDE.idea:
          _processor =
              IdeaRunConfigurationsProcessor(K.ideaLaunchpath, _flavors);
          break;
        case IDE.vscode:
          _processor = VSCodeLaunchFileProcessor(_flavors);
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
    return 'IDEProcessor: ${_ide == null ? 'Skipping IDE file generation' : super.toString()}';
  }
}
