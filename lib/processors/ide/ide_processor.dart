import 'package:flutter_flavorizr/parser/models/enums.dart';
import 'package:flutter_flavorizr/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/processors/commons/abstract_processor.dart';
import 'package:flutter_flavorizr/processors/ide/idea/idea_run_configurations_processor.dart';
import 'package:flutter_flavorizr/processors/ide/vscode/vscode_launch_file_processor.dart';
import 'package:flutter_flavorizr/utils/constants.dart';

class IDEProcessor extends AbstractProcessor {
  final AbstractProcessor? _processor;

  IDEProcessor({
    required Flavorizr config,
  })  : _processor = initProcessor(config),
        super(config);

  @override
  void execute() {
    _processor?.execute();
  }

  @override
  String toString() {
    return 'IDEProcessor: ${config.ide == null ? 'Skipping IDE file generation' : super.toString()}';
  }

  static initProcessor(Flavorizr config) {
    if (config.ide != null) {
      switch (config.ide) {
        case IDE.idea:
          return IdeaRunConfigurationsProcessor(
            K.ideaLaunchpath,
            config: config,
          );
        case IDE.vscode:
          return VSCodeLaunchFileProcessor(config: config);
        default:
          break;
      }
    }
  }
}
