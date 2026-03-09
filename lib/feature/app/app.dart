import 'dart:io';

import 'package:flutter/material.dart' hide Router;
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/navigation/navigation_screen.dart';
import 'package:trusttunnel/feature/server/server_details/model/server_details_data.dart';
import 'package:window_manager/window_manager.dart';

class App extends StatefulWidget {
  final ValueNotifier<ServerDetailsData?>? pendingDeepLink;

  const App({super.key, this.pendingDeepLink});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WindowListener {
  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) windowManager.addListener(this);
  }

  @override
  void dispose() {
    if (_isDesktop) windowManager.removeListener(this);
    super.dispose();
  }

  /// Intercept the close button — hide to tray instead of quitting.
  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: context.dependencyFactory.lightThemeData,
    home: NavigationScreen(pendingDeepLink: widget.pendingDeepLink),
    onGenerateTitle: (context) => context.ln.appTitle,
    locale: Localization.defaultLocale,
    localizationsDelegates: Localization.localizationDelegates,
    supportedLocales: Localization.supportedLocales,
  );
}
