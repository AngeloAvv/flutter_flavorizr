import 'package:flutter_flavorizr/src/processors/android/icons/android_adaptive_icon_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/image_resizer_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';

class AndroidAdaptiveIconsProcessor extends QueueProcessor {
  static const _entries = {
    'drawable-mdpi': Size(width: 108, height: 108),
    'drawable-hdpi': Size(width: 162, height: 162),
    'drawable-xhdpi': Size(width: 216, height: 216),
    'drawable-xxhdpi': Size(width: 324, height: 324),
    'drawable-xxxhdpi': Size(width: 432, height: 432),
  };

  final String foregroundSource;
  final String backgroundSource;
  final String flavorName;

  AndroidAdaptiveIconsProcessor(
    this.foregroundSource,
    this.backgroundSource,
    this.flavorName, {
    String? monochromeSource,
    required super.config,
    required super.logger,
  }) : super(
          _entries.map(
            (folder, size) {
              return MapEntry(
                folder,
                AndroidAdaptiveIconProcessor(
                  foregroundSource,
                  backgroundSource,
                  flavorName,
                  folder,
                  size,
                  config: config,
                  monochromeSource: monochromeSource,
                  logger: logger,
                ),
              );
            },
          ).values,
        );

  @override
  String toString() => 'AndroidAdaptiveIconsProcessor: { '
      'foregroundSource: $foregroundSource, '
      'backgroundSource: $backgroundSource, '
      'flavorName: $flavorName }';
}
