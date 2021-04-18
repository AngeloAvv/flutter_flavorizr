import 'package:flutter_flavorizr/parser/models/enums.dart';
import 'package:flutter_flavorizr/processors/commons/abstract_processor.dart';
import 'package:flutter_flavorizr/processors/ide/idea/idea_run_configurations_processor.dart';
import 'package:flutter_flavorizr/processors/ide/vscode/vscode_launch_file_processor.dart';
import 'package:flutter_flavorizr/utils/constants.dart';

class IDEProcessor extends AbstractProcessor {
  final IDE? ide;
  final Iterable<String> flavors;
  final AbstractProcessor? _processor;

  IDEProcessor({
    this.ide,
    required this.flavors,
  }) : _processor = initProcessor(
          flavors,
          ide: ide,
        );

  @override
  void execute() {
    _processor?.execute();
  }

  @override
  String toString() {
    return 'IDEProcessor: ${ide == null ? 'Skipping IDE file generation' : super.toString()}';
  }

  static initProcessor(Iterable<String> _flavors, {IDE? ide}) {
    if (ide != null) {
      switch (ide) {
        case IDE.idea:
          return IdeaRunConfigurationsProcessor(K.ideaLaunchpath, _flavors);
        case IDE.vscode:
          return VSCodeLaunchFileProcessor(_flavors);
        default:
          break;
      }
    }
  }
}
