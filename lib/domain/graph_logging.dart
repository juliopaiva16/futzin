// Graph action instrumentation (MT1 Event Instrumentation)
// Provides lightweight JSONL logger for per-action micro events in the graph engine.

import 'dart:convert';
import 'dart:io';

class GraphActionLog {
  final String? bodyPart; // MT5: header/foot/other (optional)
  final String matchId;
  final int minute;
  final int possessionId;
  final int actionIndex; // 0-based index within possession
  final String actionType; // pass|dribble|longPass|backPass|hold|launch|shot|goal|intercept|foul
  final String side; // 'A' or 'B'
  final String fromPlayerId;
  final String? toPlayerId;
  final double? fromX;
  final double? fromY;
  final double? toX;
  final double? toY;
  final double? preXg; // xG total for side before this action (optional)
  final double? xgDelta; // delta contributed (shot/goal)
  final bool isShot;
  final bool isGoal;
  final double? passDist;
  final double? pressureScore; // placeholder (future)
  final String? bodyPart; // MT5+ placeholder: 'foot','head','other'

  GraphActionLog({
    required this.matchId,
    required this.minute,
    required this.possessionId,
    required this.actionIndex,
    required this.actionType,
    required this.side,
    required this.fromPlayerId,
    this.toPlayerId,
    this.fromX,
    this.fromY,
    this.toX,
    this.toY,
    this.preXg,
    this.xgDelta,
    this.isShot = false,
    this.isGoal = false,
    this.passDist,
    this.pressureScore,
  this.bodyPart,
    this.bodyPart,
  });

  Map<String, dynamic> toJson() => {
        'm': matchId,
        'min': minute,
        'pid': possessionId,
        'ai': actionIndex,
        't': actionType,
        's': side,
        'fp': fromPlayerId,
        if (toPlayerId != null) 'tp': toPlayerId,
        if (fromX != null) 'fx': fromX,
        if (fromY != null) 'fy': fromY,
        if (toX != null) 'tx': toX,
        if (toY != null) 'ty': toY,
        if (preXg != null) 'pre': preXg,
        if (xgDelta != null) 'dxg': xgDelta,
        if (isShot) 'shot': 1,
        if (isGoal) 'goal': 1,
        if (passDist != null) 'dist': passDist,
  if (pressureScore != null) 'prs': pressureScore,
  if (bodyPart != null) 'bp': bodyPart,
  if (bodyPart != null) 'bp': bodyPart,
      };
}

abstract class GraphEventLogger {
  void log(GraphActionLog entry);
  void flush();
  void close();
}

class JsonlGraphEventLogger implements GraphEventLogger {
  final IOSink _sink;
  final int batchSize;
  final List<GraphActionLog> _buf = [];
  bool _closed = false;

  JsonlGraphEventLogger(String filePath, {this.batchSize = 64})
      : _sink = File(filePath).openWrite(mode: FileMode.write, encoding: utf8);

  @override
  void log(GraphActionLog entry) {
    if (_closed) return;
    _buf.add(entry);
    if (_buf.length >= batchSize) flush();
  }

  @override
  void flush() {
    if (_closed || _buf.isEmpty) return;
    final sb = StringBuffer();
    for (final e in _buf) {
      sb.writeln(jsonEncode(e.toJson()));
    }
    _sink.write(sb.toString());
    _buf.clear();
  }

  @override
  void close() {
    if (_closed) return;
    flush();
    _sink.close();
    _closed = true;
  }
}
