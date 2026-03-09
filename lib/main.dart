import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Router;
import 'package:flutter/material.dart';
import 'package:trusttunnel/di/model/initialization_helper.dart';
import 'package:trusttunnel/di/widgets/dependency_scope.dart';
import 'package:trusttunnel/feature/app/app.dart';
import 'package:trusttunnel/feature/app/tray_service.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:window_manager/window_manager.dart';

void main() => runZonedGuarded(
  () async {
    WidgetsFlutterBinding.ensureInitialized();

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(true);
      await windowManager.setTitle('TrustTunnel');
      await windowManager.setMinimumSize(const Size(800, 600));
    }

    final initializationResult = await InitializationHelperIo().init();

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await TrayService.instance.init(
        onToggle: () {}, // replaced by TrayService.setToggleCallback in VpnScope
        onShow: () => windowManager.show(),
        onQuit: () async {
          await TrayService.instance.dispose();
          await windowManager.destroy();
        },
      );
    }

    runApp(
      DependencyScope(
        dependenciesFactory: initializationResult.dependenciesFactory,
        repositoryFactory: initializationResult.repositoryFactory,
        child: ServersScope(
          child: RoutingScope(
            child: ExcludedRoutesScope(
              child: VpnScope(
                vpnRepository: initializationResult.repositoryFactory.vpnRepository,
                initialState: initializationResult.initialVpnState,
                child: const App(),
              ),
            ),
          ),
        ),
      ),
    );
  },
  (e, st) {
    print('Error catched in main thread $e');
  },
);
