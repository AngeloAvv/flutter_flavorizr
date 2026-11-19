/*
 * Copyright (c) 2026 Angelo Cassano
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

import 'package:flutter_flavorizr/src/entrypoint/output/output_environment.dart';
import 'package:test/test.dart';

void main() {
  OutputEnvironment env({
    bool stdout = true,
    bool stderr = true,
    bool stdin = true,
    bool ansi = true,
    Map<String, String> variables = const {},
  }) => OutputEnvironment(
    stdoutIsTerminal: stdout,
    stderrIsTerminal: stderr,
    stdinIsTerminal: stdin,
    supportsAnsi: ansi,
    variables: variables,
  );

  group('a terminal', () {
    test('animates and colours', () {
      expect(env().animated, isTrue);
      expect(env().color, isTrue);
      expect(env().interactive, isTrue);
    });

    test('with no stdout is not one: output is piped', () {
      final piped = env(stdout: false);

      expect(piped.animated, isFalse);
      expect(piped.color, isFalse);
      expect(piped.interactive, isFalse);
    });

    test('with no stderr is not one: warnings are redirected', () {
      expect(env(stderr: false).animated, isFalse);
      expect(env(stderr: false).color, isFalse);
    });

    test('that does not understand ANSI escapes stays linear', () {
      // A Windows console that predates virtual terminal sequences.
      expect(env(ansi: false).animated, isFalse);
      expect(env(ansi: false).color, isFalse);
    });

    test('with no stdin cannot be asked, but still animates', () {
      expect(env(stdin: false).interactive, isFalse);
      expect(env(stdin: false).animated, isTrue);
    });

    test('that is dumb stays linear', () {
      expect(env(variables: {'TERM': 'dumb'}).animated, isFalse);
      expect(env(variables: {'TERM': 'xterm-256color'}).animated, isTrue);
    });
  });

  group('NO_COLOR', () {
    test('turns the colour off and keeps the animation', () {
      final noColor = env(variables: {'NO_COLOR': '1'});

      expect(noColor.color, isFalse);
      expect(noColor.animated, isTrue);
    });

    test('counts whatever its value, but empty', () {
      expect(env(variables: {'NO_COLOR': 'false'}).color, isFalse);
      expect(env(variables: {'NO_COLOR': ''}).color, isTrue);
    });
  });

  group('a CI', () {
    test('is linear even when it hands out a terminal', () {
      expect(env(variables: {'CI': 'true'}).animated, isFalse);
      expect(env(variables: {'CI': '1'}).color, isFalse);
    });

    test('is not CI=false, CI=0 or an empty CI', () {
      expect(env(variables: {'CI': 'false'}).animated, isTrue);
      expect(env(variables: {'CI': '0'}).animated, isTrue);
      expect(env(variables: {'CI': ''}).animated, isTrue);
    });

    for (final name in [
      'GITHUB_ACTIONS',
      'GITLAB_CI',
      'BUILDKITE',
      'CIRCLECI',
      'JENKINS_URL',
      'TF_BUILD',
    ]) {
      test('is told by $name', () {
        expect(env(variables: {name: 'x'}).animated, isFalse);
      });
    }

    test('can still be answered when there is a terminal', () {
      expect(env(variables: {'CI': 'true'}).interactive, isTrue);
    });
  });

  test('the plain environment is a pipe', () {
    const plain = OutputEnvironment.plain();

    expect(plain.animated, isFalse);
    expect(plain.color, isFalse);
    expect(plain.interactive, isFalse);
  });

  test('the current one can be told, whatever the machine', () {
    final current = OutputEnvironment.current();

    // What it is depends on who runs the tests: what must hold is that colour
    // needs the animation.
    expect(!current.color || current.animated, isTrue);
  });
}
