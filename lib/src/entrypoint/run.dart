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

import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/parser.dart';
import 'package:flutter_flavorizr/src/processors/processor.dart';
import 'package:mason_logger/mason_logger.dart';

/// A common entry point to parse command line arguments and execute the process
///
/// Returns the exit code that should be set when the calling process exits. `0`
/// implies success.
void execute(List<String> args) {
  final argParser = ArgParser()
    ..addFlag('force', abbr: 'f')
    ..addMultiOption(
      'processors',
      abbr: 'p',
      allowed: Processor.defaultInstructionSet,
      splitCommas: true,
    )
    ..addFlag('verbose', abbr: 'v');

  final results = argParser.parse(args);
  final force = results['force'] as bool? ?? false;
  final argProcessors = results['processors'];
  final level = results['verbose'] == true ? Level.verbose : Level.info;

  final logger = Logger(level: level);

  const parser = Parser(
    pubspecPath: 'pubspec',
    flavorizrPath: 'flavorizr',
  );

  late Flavorizr flavorizr;
  try {
    flavorizr = parser.parse();
  } catch (error) {
    logger.err(error.toString());
    exit(65);
  }

  if (argProcessors.isNotEmpty) {
    flavorizr.instructions = argProcessors;
  }

  final processor = Processor(
    flavorizr,
    force: force,
    logger: logger,
  );
  processor.execute();
}
