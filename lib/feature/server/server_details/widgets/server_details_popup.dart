import 'package:flutter/material.dart';
import 'package:trusttunnel/feature/server/server_details/model/server_details_data.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_view.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class ServerDetailsPopUp extends StatelessWidget {
  final int? serverId;
  final ServerDetailsData? initialData;

  const ServerDetailsPopUp({
    super.key,
    this.serverId,
    this.initialData,
  });

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: ServerDetailsScope(
      serverId: serverId,
      initialData: initialData,
      child: const ServerDetailsView(),
    ),
  );
}
