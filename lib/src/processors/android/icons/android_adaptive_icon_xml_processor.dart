import 'package:flutter_flavorizr/src/parser/models/flavors/android/adaptive_icon.dart';
import 'package:flutter_flavorizr/src/processors/android/icons/android_generate_iclauncher_xml_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/new_file_string_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:sprintf/sprintf.dart';

class AndroidAdaptiveIconXmlProcessor extends QueueProcessor {
  AndroidAdaptiveIconXmlProcessor(
    AdaptiveIcon adaptiveIcon,
    String? flavorName, {
    required super.config,
    required super.logger,
  }) : super(
          [
            NewFileStringProcessor(
              sprintf(K.androidAdaptiveIconXmlPath, [flavorName]),
              AndroidGenerateIclauncherXmlProcessor(
                adaptiveIcon: adaptiveIcon,
                config: config,
                logger: logger,
              ),
              config: config,
              logger: logger,
            ),
          ],
        );

  @override
  String toString() => 'AndroidAdaptiveIconXmlProcessor';
}
