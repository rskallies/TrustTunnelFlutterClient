import 'dart:io';

import 'package:trusttunnel/data/model/vpn_protocol.dart';
import 'package:trusttunnel/feature/server/server_details/model/server_details_data.dart';
import 'package:vpn_plugin/platform_api.g.dart';

/// Decodes a `tt://` URI into a [ServerDetailsData] for pre-filling the
/// add-server form.
///
/// Returns `null` if decoding is not supported on the current platform,
/// the URI is empty, or the native decoder returns an error.
Future<ServerDetailsData?> decodeDeepLink(String uri) async {
  if (uri.isEmpty) return null;
  if (!Platform.isWindows) return null;

  final String toml;
  try {
    toml = await IDeepLink().decode(uri: uri);
  } catch (_) {
    return null;
  }

  if (toml.isEmpty) return null;
  return _parseEndpointToml(toml);
}

/// Minimal TOML parser for the `[endpoint]` section produced by
/// `trusttunnel_deeplink_decode`. Only extracts the fields needed to
/// pre-fill the add-server form.
ServerDetailsData _parseEndpointToml(String toml) {
  final values = <String, String>{};
  final addressList = <String>[];

  for (final line in toml.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('[') || trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final eq = trimmed.indexOf('=');
    if (eq < 0) continue;

    final key = trimmed.substring(0, eq).trim();
    final rawValue = trimmed.substring(eq + 1).trim();

    if (key == 'addresses') {
      // May appear as a single-line TOML array: ["1.2.3.4:443", ...]
      // Or as a bare repeated key (handled per-line by the Rust serialiser).
      final inner = rawValue.replaceAll(RegExp(r'^\[|\]$'), '');
      for (final part in inner.split(',')) {
        final addr = _unquote(part.trim());
        if (addr.isNotEmpty) addressList.add(addr);
      }
    } else {
      values[key] = _unquote(rawValue);
    }
  }

  // addresses = ["ip:port"] — take only the IP part of the first entry.
  String ipAddress = '';
  if (addressList.isNotEmpty) {
    final addr = addressList.first;
    // Strip port: handle both "1.2.3.4:443" and "[::1]:443"
    if (addr.startsWith('[')) {
      // IPv6 with port: [addr]:port
      final bracket = addr.indexOf(']');
      ipAddress = addr.substring(1, bracket > 0 ? bracket : addr.length);
    } else {
      ipAddress = addr.contains(':') ? addr.substring(0, addr.lastIndexOf(':')) : addr;
    }
  }

  final hostname = values['hostname'] ?? '';
  final protocol = (values['upstream_protocol'] ?? 'http2') == 'http3'
      ? VpnProtocol.quic
      : VpnProtocol.http2;

  return ServerDetailsData(
    serverName: hostname,
    ipAddress: ipAddress,
    domain: hostname,
    username: values['username'] ?? '',
    password: values['password'] ?? '',
    protocol: protocol,
  );
}

String _unquote(String s) {
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    return s.substring(1, s.length - 1);
  }
  return s;
}
