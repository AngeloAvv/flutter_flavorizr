import 'package:flutter_flavorizr/src/parser/models/enums.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/abstract_processor.dart';
import 'package:flutter_flavorizr/src/processors/ide/idea/idea_run_configurations_processor.dart';
import 'package:flutter_flavorizr/src/processors/ide/vscode/vscode_launch_file_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

class IDEProcessor extends AbstractProcessor {
  final List<AbstractProcessor>? _processors;

  IDEProcessor({
    required Flavorizr config,
  })  : _processors = initProcessor(config),
        super(config);

  @override
  void execute() {
    if (_processors != null) {
      for (final processor in _processors!) {
        processor.execute();
      }
    }
  }

  @override
  String toString() {
    return 'IDEProcessor: ${config.ide == null ? 'Skipping IDE file generation' : super.toString()}';
  }

  static List<AbstractProcessor>? initProcessor(Flavorizr config) {
    final List<AbstractProcessor> processors = <AbstractProcessor>[];
    final List<IDE> ides = <IDE>[];

    if (config.ide != null) {
      ides.add(config.ide!);
    }
    if (config.ides != null && config.ides!.isNotEmpty) {
      ides.addAll(config.ides!);
    }

    for (final ide in ides.toSet()) {
      processors.add(switch (ide) {
        IDE.idea => IdeaRunConfigurationsProcessor(
            K.ideaLaunchpath,
            config: config,
          ),
        IDE.vscode => VSCodeLaunchFileProcessor(config: config),
      });
    }
    return processors;
  }
}
