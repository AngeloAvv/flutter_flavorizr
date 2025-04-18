import 'package:flutter_flavorizr/src/parser/models/enums.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/abstract_processor.dart';
import 'package:flutter_flavorizr/src/processors/ide/idea/idea_run_configurations_processor.dart';
import 'package:flutter_flavorizr/src/processors/ide/vscode/vscode_launch_file_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:mason_logger/mason_logger.dart';

class IDEProcessor extends AbstractProcessor {
  final AbstractProcessor? _processor;

  IDEProcessor({
    required Flavorizr config,
    required Logger logger,
  })  : _processor = initProcessor(config, logger: logger),
        super(config, logger: logger);

  @override
  void execute() {
    if (config.ide == null) {
      logger.detail(
        'No IDE processor found. Skipping IDE file generation.',
        style: logger.theme.warn,
      );
    }

    _processor?.execute();
  }

  @override
  String toString() => 'IDEProcessor';

  static initProcessor(Flavorizr config, {required Logger logger}) =>
      switch (config.ide) {
        IDE.idea => IdeaRunConfigurationsProcessor(
            K.ideaLaunchpath,
            config: config,
            logger: logger,
          ),
        IDE.vscode => VSCodeLaunchFileProcessor(
            config: config,
            logger: logger,
          ),
        _ => null,
      };
}
