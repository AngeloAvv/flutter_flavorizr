import 'package:flutter_flavorizr/src/parser/models/enums.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';
import 'package:flutter_flavorizr/src/processors/ide/idea/idea_run_configurations_processor.dart';
import 'package:flutter_flavorizr/src/processors/ide/vscode/vscode_launch_file_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

class IDEProcessor extends QueueProcessor {
  IDEProcessor({
    required super.config,
    required super.logger,
  }) : super([
          ...?config.ide?.map(
            (ide) => switch (ide) {
              IDE.idea => IdeaRunConfigurationsProcessor(
                  K.ideaLaunchpath,
                  config: config,
                  logger: logger,
                ),
              IDE.vscode => VSCodeLaunchFileProcessor(
                  config: config,
                  logger: logger,
                ),
            },
          )
        ]);

  @override
  String toString() => 'IDEProcessor';
}
