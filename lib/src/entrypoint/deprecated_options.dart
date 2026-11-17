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

/// The version that removes the 2.x options `-f`/`--force`, which is `--yes`,
/// and `-p`/`--processors`, which names the targets. Until then they work, hidden
/// from the help, and every use of them warns.
const removedInVersion = '4.0';

/// The 2.x processors that are gone, which `-p` skips instead of failing.
///
/// The assets pipeline downloaded `assets.zip` from a GitHub release and
/// unzipped it, only for the dummy assets to be copied from there: the same
/// files ship inside the package (#527).
const removedProcessors = {'assets:download', 'assets:extract', 'assets:clean'};

/// What `-p` of [commandName] asked for, read the way 3.x does.
final class DeprecatedProcessors {
  /// The ids to run, which are targets: the ones that still exist.
  final List<String> targets;

  /// The ids that are gone, which were skipped.
  final List<String> dropped;

  /// What to tell the user, as warnings: `-p` is deprecated, and what was
  /// skipped and why.
  final List<String> warnings;

  const DeprecatedProcessors._({
    required this.targets,
    required this.dropped,
    required this.warnings,
  });

  /// Reads the [values] of `-p`, of the command [commandName], which has the
  /// [positional] targets besides.
  ///
  /// Whitespace and empty entries (`-p ''`, `a,,b`) are ignored, so a CI
  /// variable that is empty runs what no `-p` runs. Using `-p` at all warns, and
  /// without it there is nothing to warn about.
  factory DeprecatedProcessors.parse(
    Iterable<String> values, {
    required String commandName,
    Iterable<String> positional = const [],
  }) {
    final ids = [
      for (final value in values)
        for (final id in value.split(','))
          if (id.trim().isNotEmpty) id.trim(),
    ];
    final dropped = [
      for (final id in ids)
        if (removedProcessors.contains(id)) id,
    ];
    final targets = [
      for (final id in ids)
        if (!removedProcessors.contains(id)) id,
    ];

    return DeprecatedProcessors._(
      targets: targets,
      dropped: dropped,
      warnings: [
        if (values.isNotEmpty)
          '-p/--processors is deprecated and will be removed in '
              '$removedInVersion. Name the targets after the command instead'
              '${targets.isEmpty ? '' : ': $commandName ${[...positional, ...targets].join(' ')}'}.',
        for (final id in dropped)
          '$id was skipped: the 2.x assets pipeline no longer exists in 3.0, '
              'since the assets ship with the package (#527).',
      ],
    );
  }

  /// Whether `-p` named nothing but ids that are gone: the run is then empty,
  /// and not the default recipe `-p` never asked for.
  bool get leavesNothing => targets.isEmpty && dropped.isNotEmpty;
}

/// The warning of `-f`/`--force`.
const forceWarning =
    '-f/--force is deprecated and will be removed in $removedInVersion. '
    'Use --yes (-y) instead.';
