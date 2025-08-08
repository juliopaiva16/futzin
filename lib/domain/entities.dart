// Domain entities for the football simulation.
//
// This file defines core value types used across the app.

// ignore_for_file: public_member_api_docs, constant_identifier_names

enum Position { GK, DEF, MID, FWD }

String positionLabel(Position p) {
  switch (p) {
    case Position.GK:
      return 'GK';
    case Position.DEF:
      return 'DEF';
    case Position.MID:
      return 'MID';
    case Position.FWD:
      return 'FWD';
  }
}

class Player {
  final String id;
  String name;
  Position pos;
  int attack;
  int defense;
  int stamina;
  double currentStamina;
  int yellowCards;
  bool injured;
  bool sentOff;

  Player({
    required this.id,
    required this.name,
    required this.pos,
    required this.attack,
    required this.defense,
    required this.stamina,
    double? currentStamina,
    this.yellowCards = 0,
    this.injured = false,
    this.sentOff = false,
  }) : currentStamina = currentStamina ?? stamina.toDouble();

  Player copy() => Player(
    id: id,
    name: name,
    pos: pos,
    attack: attack,
    defense: defense,
    stamina: stamina,
    currentStamina: currentStamina,
    yellowCards: yellowCards,
    injured: injured,
    sentOff: sentOff,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pos': pos.index,
    'attack': attack,
    'defense': defense,
    'stamina': stamina,
  };

  static Player fromJson(Map<String, dynamic> j) => Player(
    id: j['id'],
    name: j['name'],
    pos: Position.values[j['pos']],
    attack: j['attack'],
    defense: j['defense'],
    stamina: j['stamina'],
  );
}

class Formation {
  final String name;
  final int def;
  final int mid;
  final int fwd;
  // Optional: how to split the midfield across rows (e.g. [2,3] for 4-2-3-1)
  final List<int>? midRows;
  const Formation(this.name, this.def, this.mid, this.fwd, {this.midRows});

  static const formations = <Formation>[
    Formation('4-3-3', 4, 3, 3),
    Formation('4-4-2', 4, 4, 2),
    // 3-5-2 typically has two central lines (e.g. 3 + 2) visually
    Formation('3-5-2', 3, 5, 2, midRows: [3, 2]),
    Formation('5-3-2', 5, 3, 2),
    // 4-2-3-1 requires splitting the mid into two rows: 2 + 3
    Formation('4-2-3-1', 4, 5, 1, midRows: [2, 3]),
  ];
}

class Tactics {
  double attackBias; // -1..+1
  double tempo; // 0..1
  double pressing; // 0..1
  double lineHeight; // 0..1
  double width; // 0..1
  bool autoSubs;

  Tactics({
    this.attackBias = 0.0,
    this.tempo = 0.5,
    this.pressing = 0.5,
    this.lineHeight = 0.5,
    this.width = 0.5,
    this.autoSubs = true,
  });

  Tactics copyWith({
    double? attackBias,
    double? tempo,
    double? pressing,
    double? lineHeight,
    double? width,
    bool? autoSubs,
  }) {
    return Tactics(
      attackBias: attackBias ?? this.attackBias,
      tempo: tempo ?? this.tempo,
      pressing: pressing ?? this.pressing,
      lineHeight: lineHeight ?? this.lineHeight,
      width: width ?? this.width,
      autoSubs: autoSubs ?? this.autoSubs,
    );
  }

  Map<String, dynamic> toJson() => {
    'attackBias': attackBias,
    'tempo': tempo,
    'pressing': pressing,
    'lineHeight': lineHeight,
    'width': width,
    'autoSubs': autoSubs,
  };

  static Tactics fromJson(Map<String, dynamic> j) => Tactics(
    attackBias: (j['attackBias'] ?? 0.0) * 1.0,
    tempo: (j['tempo'] ?? 0.5) * 1.0,
    pressing: (j['pressing'] ?? 0.5) * 1.0,
    lineHeight: (j['lineHeight'] ?? 0.5) * 1.0,
    width: (j['width'] ?? 0.5) * 1.0,
    autoSubs: j['autoSubs'] ?? true,
  );
}

class TeamConfig {
  String name;
  Formation formation;
  Tactics tactics;
  final List<Player> squad;
  final Set<String> selectedIds = {}; // players on field by id
  int subsLeft = 5;

  TeamConfig({
    required this.name,
    required this.formation,
    required this.tactics,
    required this.squad,
  });

  Player? byId(String id) => squad.firstWhere(
    (p) => p.id == id,
    orElse: () => Player(
      id: 'X',
      name: 'X',
      pos: Position.MID,
      attack: 1,
      defense: 1,
      stamina: 1,
    ),
  );

  List<Player> get selected =>
      squad.where((p) => selectedIds.contains(p.id)).toList();
  List<Player> get bench =>
      squad.where((p) => !selectedIds.contains(p.id)).toList();

  bool get hasValidGK =>
      selected
          .where((p) => p.pos == Position.GK && !p.sentOff && !p.injured)
          .length ==
      1;
  int get needDEF => formation.def;
  int get needMID => formation.mid;
  int get needFWD => formation.fwd;
  int get selectedDEF => selected.where((p) => p.pos == Position.DEF).length;
  int get selectedMID => selected.where((p) => p.pos == Position.MID).length;
  int get selectedFWD => selected.where((p) => p.pos == Position.FWD).length;
  int get selectedGK => selected.where((p) => p.pos == Position.GK).length;

  bool get isLineupValid =>
      hasValidGK &&
      selectedDEF == needDEF &&
      selectedMID == needMID &&
      selectedFWD == needFWD &&
      selected.length == 11;

  void autoPick() {
    selectedIds.clear();
    final gks =
        squad
            .where((p) => p.pos == Position.GK && !p.sentOff && !p.injured)
            .toList()
          ..sort(
            (a, b) => (b.defense + b.attack).compareTo(a.defense + a.attack),
          );
    if (gks.isNotEmpty) selectedIds.add(gks.first.id);

    final defs =
        squad
            .where((p) => p.pos == Position.DEF && !p.sentOff && !p.injured)
            .toList()
          ..sort(
            (a, b) =>
                (b.defense * 2 + b.attack).compareTo(a.defense * 2 + a.attack),
          );
    selectedIds.addAll(defs.take(needDEF).map((e) => e.id));

    final mids =
        squad
            .where((p) => p.pos == Position.MID && !p.sentOff && !p.injured)
            .toList()
          ..sort(
            (a, b) => (b.attack + b.defense).compareTo(a.attack + a.defense),
          );
    selectedIds.addAll(mids.take(needMID).map((e) => e.id));

    final fwds =
        squad
            .where((p) => p.pos == Position.FWD && !p.sentOff && !p.injured)
            .toList()
          ..sort(
            (a, b) =>
                (b.attack * 2 + b.defense).compareTo(a.attack * 2 + a.defense),
          );
    selectedIds.addAll(fwds.take(needFWD).map((e) => e.id));
  }

  bool canSelect(Player p) {
    if (selectedIds.contains(p.id)) return true;
    switch (p.pos) {
      case Position.GK:
        return selectedGK < 1;
      case Position.DEF:
        return selectedDEF < needDEF;
      case Position.MID:
        return selectedMID < needMID;
      case Position.FWD:
        return selectedFWD < needFWD;
    }
  }

  bool makeSub(Player out, Player inn) {
    if (subsLeft <= 0) return false;
    if (!selectedIds.contains(out.id)) return false;
    if (selectedIds.contains(inn.id)) return false;
    if (out.sentOff) return false; // cannot replace a red card
    selectedIds.remove(out.id);
    selectedIds.add(inn.id);
    subsLeft--;
    return true;
  }

  void resetRuntime() {
    subsLeft = 5;
    for (final p in squad) {
      p.currentStamina = p.stamina.toDouble().clamp(0, 100);
      p.yellowCards = 0;
      p.injured = false;
      p.sentOff = false;
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'formation': formation.name,
    'tactics': tactics.toJson(),
    'squad': squad.map((p) => p.toJson()).toList(),
    'selected': selectedIds.toList(),
  };

  static TeamConfig fromJson(Map<String, dynamic> j) {
    final squad = (j['squad'] as List).map((e) => Player.fromJson(e)).toList();
    final formName = j['formation'];
    final form = Formation.formations.firstWhere(
      (f) => f.name == formName,
      orElse: () => Formation.formations.first,
    );
    final t = Tactics.fromJson(j['tactics']);
    final tc = TeamConfig(
      name: j['name'],
      formation: form,
      tactics: t,
      squad: squad,
    );
    tc.selectedIds.addAll((j['selected'] as List).map((e) => e.toString()));
    return tc;
  }
}
