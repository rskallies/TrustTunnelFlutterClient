import 'dart:io';

import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/utils/url_utils.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/excluded_routes_screen.dart';
import 'package:trusttunnel/feature/settings/query_log/widgets/query_log_screen.dart';
import 'package:trusttunnel/feature/settings/settings_about/about_screen.dart';
import 'package:trusttunnel/widgets/common/custom_arrow_list_tile.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _debugLogging = false;

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: Scaffold(
      appBar: CustomAppBar(
        title: context.ln.settings,
      ),
      body: ListView(
        children: [
          CustomArrowListTile(
            title: context.ln.queryLog,
            onTap: () => _pushQueryLogScreen(context),
          ),
          const Divider(),
          CustomArrowListTile(
            title: context.ln.excludedRoutes,
            onTap: () => _pushExcludedRoutesScreen(context),
          ),
          const Divider(),
          CustomArrowListTile(
            title: context.ln.followUsOnGithub,
            onTap: _openGithubOrganization,
          ),
          const Divider(),
          CustomArrowListTile(
            title: context.ln.about,
            onTap: () => _pushAboutScreen(context),
          ),
          if (Platform.isWindows) ...[
            const Divider(),
            SwitchListTile(
              title: const Text('Debug logging'),
              subtitle: const Text('Write vpn_easy engine logs to %TEMP%\\vpn_easy_engine.log'),
              value: _debugLogging,
              onChanged: (value) {
                setState(() => _debugLogging = value);
                context.repositoryFactory.vpnRepository.setDebugLogging(enabled: value);
              },
            ),
          ],
        ],
      ),
    ),
  );

  void _pushQueryLogScreen(BuildContext context) => context.push(
    const QueryLogScreen(),
  );

  void _pushExcludedRoutesScreen(BuildContext context) => context.push(
    const ExcludedRoutesScreen(),
  );

  void _openGithubOrganization() => UrlUtils.openWebPage(UrlUtils.githubTrustTunnelTeam);

  void _pushAboutScreen(BuildContext context) => context.push(
    const AboutScreen(),
  );
}
