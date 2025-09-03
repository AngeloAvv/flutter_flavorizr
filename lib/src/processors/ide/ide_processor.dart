import 'package:flutter_flavorizr/src/parser/models/enums.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/abstract_processor.dart';
import 'package:flutter_flavorizr/src/processors/ide/idea/idea_run_configurations_processor.dart';
import 'package:flutter_flavorizr/src/processors/ide/vscode/vscode_launch_file_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:mason_logger/mason_logger.dart';

class IDEProcessor extends AbstractProcessor {
  final List<AbstractProcessor>? _processors;

  IDEProcessor({
    required Flavorizr config,
    required Logger logger,
  })  : _processors = initProcessor(config, logger: logger),
        super(config, logger: logger);

  @override
  void execute() {
    if (_processors == null || _processors!.isEmpty) {
      logger.detail(
        'No IDE processor found. Skipping IDE file generation.',
        style: logger.theme.warn,
      );
    } else {
      for (final processor in _processors!) {
        processor.execute();
      }
    }
  }

  @override
  String toString() => 'IDEProcessor';

  static List<AbstractProcessor>? initProcessor(Flavorizr config,
      {required Logger logger}) {
    final List<AbstractProcessor> processors = <AbstractProcessor>[];

    if (config.ide != null) {
      for (final ide in config.ide!) {
        processors.add(switch (ide) {
          IDE.idea => IdeaRunConfigurationsProcessor(
              K.ideaLaunchpath,
              config: config,
              logger: logger,
            ),
          IDE.vscode => VSCodeLaunchFileProcessor(
              config: config,
              logger: logger,
            ),
        });
      }
    }
    return processors;
  }
}
