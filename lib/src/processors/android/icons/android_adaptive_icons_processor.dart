import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
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

  String foregroundSource;
  String backgroundSource;
  String flavorName;

  AndroidAdaptiveIconsProcessor(
    this.foregroundSource,
    this.backgroundSource,
    this.flavorName, {
    required Flavorizr config,
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
                ),
              );
            },
          ).values,
          config: config,
        );

  @override
  String toString() => 'AndroidAdaptiveIconsProcessor';
}
