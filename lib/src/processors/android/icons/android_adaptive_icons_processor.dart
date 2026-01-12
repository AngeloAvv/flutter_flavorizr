import 'package:flutter_flavorizr/src/processors/android/icons/android_adaptive_icon_processor.dart';
import 'package:flutter_flavorizr/src/models/commons/size.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';

class AndroidAdaptiveIconsProcessor extends QueueProcessor {
  static const _entries = {
    'drawable-mdpi': Size(108, 108),
    'drawable-hdpi': Size(162, 162),
    'drawable-xhdpi': Size(216, 216),
    'drawable-xxhdpi': Size(324, 324),
    'drawable-xxxhdpi': Size(432, 432),
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
