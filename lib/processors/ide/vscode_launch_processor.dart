import 'package:flutter_flavorizr/processors/commons/string_processor.dart';

class VSCodeLaunchProcessor extends StringProcessor {
  final List<String> _flavorNames;

  VSCodeLaunchProcessor(this._flavorNames);

  @override
  execute() {
    List<String> modes = ['Debug', 'Profile', 'Release'];

    StringBuffer buffer = StringBuffer()
      ..writeln('{')
      ..writeln('  "version": "0.2.0",')
      ..writeln('  "configurations": [');

    _flavorNames.forEach(
      (String flavorName) {
        modes.forEach(
          (String mode) => buffer
            ..writeln('    {')
            ..writeln('      "name": "$flavorName $mode",')
            ..writeln('      "request": "launch",')
            ..writeln('      "type": "dart",')
            ..writeln('      "args": [')
            ..writeln('        "--flavor",')
            ..writeln('        "$flavorName"')
            ..writeln('      ],')
            ..writeln('      "flutterMode": "${mode.toLowerCase()}"')
            ..writeln(
                '    }${flavorName == _flavorNames.last && mode == modes.last ? '' : ','}'),
        );
      },
    );

    buffer..writeln('  ]')..writeln('}');

    return buffer.toString();
  }

  @override
  String toString() =>
      "VSCodeLaunchProcessor";
}
