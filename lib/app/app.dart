import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../presentation/pages/home_page.dart';
import '../core/localization/app_localizations.dart';

/// Root app widget configuring theme, routes, and localization.
class FutSimApp extends StatelessWidget {
  const FutSimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FutSim',
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
