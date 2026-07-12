/*
 * Copyright (c) 2024 Angelo Cassano
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/abstract_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../test_utils.dart';

class _RecordingProcessor extends AbstractProcessor<void> {
  final String name;
  final List<String> calls;

  _RecordingProcessor(
    this.name,
    this.calls,
    super.config, {
    required super.logger,
  });

  @override
  void execute() {
    calls.add(name);
  }

  @override
  String toString() => 'RecordingProcessor($name)';
}

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test('Test QueueProcessor executes processors in order', () async {
    final calls = <String>[];
    final processors = [
      _RecordingProcessor('first', calls, flavorizr, logger: logger),
      _RecordingProcessor('second', calls, flavorizr, logger: logger),
      _RecordingProcessor('third', calls, flavorizr, logger: logger),
    ];

    final queueProcessor = QueueProcessor(
      processors,
      config: flavorizr,
      logger: logger,
    );

    await queueProcessor.execute();

    expect(calls, ['first', 'second', 'third']);
  });

  test('Test QueueProcessor with empty processors list is a no-op', () async {
    final queueProcessor = QueueProcessor(
      const <AbstractProcessor>[],
      config: flavorizr,
      logger: logger,
    );

    await expectLater(queueProcessor.execute(), completes);
  });

}
