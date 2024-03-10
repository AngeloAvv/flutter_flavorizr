import 'package:flutter_flavorizr/src/processors/commons/shell_processor.dart';

class XcodeprojProcessor extends ShellProcessor {
  XcodeprojProcessor({
    required super.config,
  }) : super(
          'gem',
          [
            'list',
            '-i',
            '^xcodeproj\$',
          ],
        );

  @override
  void execute() {
    try {
      super.execute();
    } catch (_) {
      throw Exception('Xcodeproj is not installed. Please install it by running `gem install xcodeproj`');
    }
  }

  @override
  String toString() => 'XcodeprojProcessor: Checking if xcodeproj is installed';
}
