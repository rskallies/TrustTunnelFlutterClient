import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/feature/app/deep_link_service.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_popup.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_aspect.dart';
import 'package:trusttunnel/feature/server/servers/widget/servers_card.dart';
import 'package:trusttunnel/feature/server/servers/widget/servers_empty_placeholder.dart';
import 'package:trusttunnel/widgets/buttons/custom_floating_action_button.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class ServersScreenView extends StatefulWidget {
  const ServersScreenView({
    super.key,
  });

  @override
  State<ServersScreenView> createState() => _ServersScreenViewState();
}

class _ServersScreenViewState extends State<ServersScreenView> {
  late List<Server> _servers;

  @override
  void initState() {
    super.initState();
    final initialController = ServersScope.controllerOf(context, listen: false);
    _servers = initialController.servers;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _servers = ServersScope.controllerOf(
      context,
      aspect: ServersScopeAspect.servers,
    ).servers;
  }

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: ScaffoldMessenger(
      child: Scaffold(
        appBar: CustomAppBar(
          title: context.ln.servers,
          actions: [
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: 'Import from tt:// link',
              onPressed: () => _showImportDialog(context),
            ),
          ],
        ),
        body: _servers.isEmpty
            ? const ServersEmptyPlaceholder()
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: _servers.length,
                itemBuilder: (_, index) => Column(
                  children: [
                    ServersCard(
                      server: _servers[index],
                    ),

                    if (index != _servers.length - 1) const Divider(),
                  ],
                ),
              ),
        floatingActionButton: _servers.isEmpty
            ? const SizedBox.shrink()
            : Builder(
                builder: (context) => CustomFloatingActionButton.extended(
                  icon: AssetIcons.add,
                  onPressed: () => _pushServerDetailsScreen(context),
                  label: context.ln.addServer,
                ),
              ),
      ),
    ),
  );

  void _pushServerDetailsScreen(BuildContext context) async {
    final controller = ServersScope.controllerOf(context, listen: false);

    await context.push(
      const ServerDetailsPopUp(),
    );

    controller.fetchServers();
  }

  void _showImportDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import from tt:// link'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'tt://?...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.ln.cancel),
          ),
          TextButton(
            onPressed: () async {
              final uri = controller.text.trim();
              Navigator.of(dialogContext).pop();
              if (uri.isEmpty) return;

              final data = await decodeDeepLink(uri);
              if (!context.mounted) return;

              if (data == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid or unsupported tt:// link.')),
                );
                return;
              }

              final serversController = ServersScope.controllerOf(context, listen: false);
              await context.push(ServerDetailsPopUp(initialData: data));
              if (context.mounted) serversController.fetchServers();
            },
            child: Text(context.ln.add),
          ),
        ],
      ),
    );
  }
}
