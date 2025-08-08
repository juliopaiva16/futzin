import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';

class HubPage extends StatelessWidget {
  const HubPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.hubTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/player-market');
              },
              child: Text(l10n.navPlayerMarket),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/team-management');
              },
              child: Text(l10n.navTeamManagement),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/match');
              },
              child: Text(l10n.navGoToMatch),
            ),
          ],
        ),
      ),
    );
  }
}
