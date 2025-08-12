// Utility script to run batch sims and auto-update progress/engine.yaml metrics_current
// Usage: dart run bin/update_progress_metrics.dart --games 60
// NOTE: Parses stdout of batch_baseline.dart; keep regex patterns in sync with print lines.
import 'dart:io';

Future<void> main(List<String> args) async {
  int games = 40; // default quick sample
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--games' && i + 1 < args.length) {
      games = int.tryParse(args[i + 1]) ?? games; i++; continue;
    }
  }
  final proc = await Process.run('dart', ['run', 'bin/batch_baseline.dart', '--games', games.toString()]);
  if (proc.exitCode != 0) {
    stderr.writeln('Batch simulation failed:');
    stderr.writeln(proc.stderr);
    exit(1);
  }
  final out = proc.stdout.toString();
  stdout.writeln(out); // echo

  double? _first(RegExp r) {
    final m = r.firstMatch(out); if (m == null) return null; return double.tryParse(m.group(1)!.replaceAll('%',''));
  }

  final avgGoals = _first(RegExp(r'Avg Goals: ([0-9]+\.[0-9]+)'));
  final avgXg = _first(RegExp(r'Avg xG: ([0-9]+\.[0-9]+)'));
  final passPct = _first(RegExp(r'Pass Success \(ALL\):\s+([0-9]+\.[0-9]+)%'));
  final dribbleAttTotal = _first(RegExp(r'Dribbles: attempts=([0-9]+)'));
  final dribbleSuccPct = _first(RegExp(r'Dribbles: .*SuccessRate=([0-9]+\.[0-9]+)%'));
  if ([avgGoals, avgXg, passPct, dribbleAttTotal, dribbleSuccPct].contains(null)) {
    stderr.writeln('Parse error: one or more metrics missing.');
    exit(2);
  }
  final dribPerGame = (dribbleAttTotal! / games);
  final date = DateTime.now().toUtc();
  final dateStr = '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
  final file = File('progress/engine.yaml');
  if (!file.existsSync()) { stderr.writeln('engine.yaml not found'); exit(3); }
  var content = file.readAsStringSync();
  content = content.replaceFirst(RegExp(r'updated: \d{4}-\d{2}-\d{2}'), 'updated: $dateStr');
  final metricsPattern = RegExp(r'metrics_current: \{[^}]*\}');
  final newMetrics = 'metrics_current: { pass_pct: ${passPct!.toStringAsFixed(1)}, xg_avg: ${avgXg!.toStringAsFixed(2)}, goals_avg: ${avgGoals!.toStringAsFixed(2)}, dribble_att: ${dribPerGame.toStringAsFixed(1)}, dribble_succ_pct: ${dribbleSuccPct!.toStringAsFixed(1)} }';
  content = content.replaceFirst(metricsPattern, newMetrics);
  file.writeAsStringSync(content);
  stdout.writeln('Updated engine.yaml metrics_current + date: $dateStr');
}
