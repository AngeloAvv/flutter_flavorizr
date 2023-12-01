import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/image_resizer_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:sprintf/sprintf.dart';

class AndroidAdaptiveIconProcessor extends QueueProcessor {
  String foregroundSource;
  String backgroundSource;
  String flavorName;
  String folder;
  Size size;

  AndroidAdaptiveIconProcessor(
    this.foregroundSource,
    this.backgroundSource,
    this.flavorName,
    this.folder,
    this.size, {
    required Flavorizr config,
  }) : super([
          ImageResizerProcessor(
            foregroundSource,
            sprintf(K.androidAdaptiveIconForegroundPath, [flavorName, folder]),
            size,
            config: config,
          ),
          ImageResizerProcessor(
            backgroundSource,
            sprintf(K.androidAdaptiveIconBackgroundPath, [flavorName, folder]),
            size,
            config: config,
          ),
        ], config: config);

  @override
  String toString() => 'AndroidAdaptiveIconProcessor';
}
