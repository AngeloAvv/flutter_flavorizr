import 'package:flutter_flavorizr/src/processors/commons/image_resizer_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:sprintf/sprintf.dart';

class AndroidAdaptiveIconProcessor extends QueueProcessor {
  final String foregroundSource;
  final String backgroundSource;
  final String flavorName;
  final String folder;
  final Size size;

  AndroidAdaptiveIconProcessor(
    this.foregroundSource,
    this.backgroundSource,
    this.flavorName,
    this.folder,
    this.size, {
    String? monochromeSource,
    required super.config,
    required super.logger,
  }) : super(
          [
            ImageResizerProcessor(
              foregroundSource,
              sprintf(
                  K.androidAdaptiveIconForegroundPath, [flavorName, folder]),
              size,
              config: config,
              logger: logger,
            ),
            ImageResizerProcessor(
              backgroundSource,
              sprintf(
                  K.androidAdaptiveIconBackgroundPath, [flavorName, folder]),
              size,
              config: config,
              logger: logger,
            ),
            if (monochromeSource != null)
              ImageResizerProcessor(
                monochromeSource,
                sprintf(
                    K.androidAdaptiveIconMonochromePath, [flavorName, folder]),
                size,
                config: config,
                logger: logger,
              ),
          ],
        );

  @override
  String toString() => 'AndroidAdaptiveIconProcessor: { '
      'foregroundSource: $foregroundSource, '
      'backgroundSource: $backgroundSource, '
      'flavorName: $flavorName, '
      'folder: $folder, '
      'size: $size }';
}
