import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_localizations.dart';

import '../../domain/entities.dart';
import '../widgets/team_config_widget.dart';

class TeamManagementPage extends StatefulWidget {
  const TeamManagementPage({Key? key}) : super(key: key);

  @override
  State<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage> {
  TeamConfig? teamA;
  TeamConfig? teamB;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final data = sp.getString('futsim_state_v1');
    if (data != null) {
      try {
        final j = jsonDecode(data) as Map<String, dynamic>;
        teamA = TeamConfig.fromJson(j['teamA']);
        teamB = TeamConfig.fromJson(j['teamB']);
      } catch (_) {}
    }
    teamA ??= TeamConfig(
      name: 'Time A',
      formation: Formation.formations.first,
      tactics: Tactics(),
      squad: [],
    )..autoPick();
    teamB ??= TeamConfig(
      name: 'Time B',
      formation: Formation.formations[1],
      tactics: Tactics(),
      squad: [],
    )..autoPick();
    setState(() => loading = false);
  }

  Future<void> _save() async {
    if (teamA == null || teamB == null) return;
    final sp = await SharedPreferences.getInstance();
    final j = {'teamA': teamA!.toJson(), 'teamB': teamB!.toJson()};
    await sp.setString('futsim_state_v1', jsonEncode(j));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.teamManagementTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
            tooltip: l10n.save,
          )
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                TeamConfigWidget(
                  title: 'Meu Time',
                  team: teamA!,
                  simRunning: false,
                  onChanged: _save,
                  onSubstitute: (o, i) {
                    // No-op here; subs are mainly for live match
                  },
                ),
                const SizedBox(height: 12),
                TeamConfigWidget(
                  title: 'Adversário',
                  team: teamB!,
                  simRunning: false,
                  onChanged: _save,
                  onSubstitute: (o, i) {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
