import 'package:flutter_flavorizr/src/extensions/extensions_map.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/android/icons/android_adaptive_icon_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/icons/android_adaptive_icon_xml_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';

class AndroidAdaptiveIconsProcessor extends QueueProcessor {
  AndroidAdaptiveIconsProcessor({
    required Flavorizr config,
  }) : super(
          config.androidFlavors
              .where((_, flavor) =>
                  flavor.android!.adaptiveIcon!['foreground'] != null &&
                  flavor.android!.adaptiveIcon!['background'] != null)
              .map((flavorName, flavor) => MapEntry(
                    flavorName,
                    QueueProcessor([
                      AndroidAdaptiveIconXmlProcessor(flavorName,
                          config: config),
                      AndroidAdaptiveIconProcessor(
                        flavor.android!.adaptiveIcon!['foreground'] ?? '',
                        flavor.android!.adaptiveIcon!['background'] ?? '',
                        flavorName,
                        config: config,
                      ),
                    ], config: config),
                  ))
              .values,
          config: config,
        );

  @override
  String toString() => 'AndroidAdaptiveIconsProcessor';
}
