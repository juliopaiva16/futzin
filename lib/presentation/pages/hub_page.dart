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
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
        child: LayoutBuilder(
          builder: (ctx, c) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _navButton(
                context,
                label: l10n.navPlayerMarket,
                route: '/player-market',
              ),
              const SizedBox(height: 24),
              _navButton(
                context,
                label: l10n.navTeamManagement,
                route: '/team-management',
              ),
              const SizedBox(height: 24),
              _navButton(
                context,
                label: l10n.navGoToMatch,
                route: '/match',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _navButton(BuildContext context, {required String label, required String route}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: () => Navigator.pushNamed(context, route),
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
      child: Text(
        label,
        textAlign: TextAlign.center,
        softWrap: true,
        maxLines: 3,
      ),
    ),
  );
}
