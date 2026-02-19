import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/data/model/certificate.dart';
import 'package:trusttunnel/data/model/vpn_protocol.dart';

/// {@template raw_server}
/// Database-oriented representation of a VPN server record.
///
/// `RawServer` is similar to `Server`, but it references a routing profile by
/// its identifier ([routingProfileId]) rather than embedding the full
/// routing profile object. This shape is typically used by persistence layers
/// and DTO-style conversions.
///
/// Instances are immutable and use value-based equality.
/// {@endtemplate}
@immutable
class RawServer {
  /// Database identifier of the server record.
  final int id;

  /// User-visible server name.
  final String name;

  /// Server IP address (usually IPv4/IPv6 literal).
  final String ipAddress;

  /// Server host name used for TLS (SNI / certificate verification).
  final String domain;

  /// Username used for authentication.
  final String username;

  /// Password used for authentication.
  final String password;

  /// Transport protocol used to communicate with the server.
  final VpnProtocol vpnProtocol;

  /// DNS upstream addresses associated with this server.
  ///
  /// The list is expected to be treated as immutable by callers.
  final List<String> dnsServers;

  /// Identifier of the routing profile associated with this server.
  final int routingProfileId;

  /// Whether this server is marked as the currently selected one.
  final bool selected;

  final Certificate? certificate;

  final String? tlsPrefix;

  final bool ipv6;

  /// {@macro raw_server}
  const RawServer({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.domain,
    required this.username,
    required this.password,
    required this.vpnProtocol,
    required this.dnsServers,
    required this.routingProfileId,
    required this.ipv6,
    this.certificate,
    this.tlsPrefix,
    this.selected = false,
  });

  @override
  int get hashCode => Object.hash(
    id,
    name,
    ipAddress,
    domain,
    username,
    password,
    vpnProtocol,
    Object.hashAll(dnsServers),
    routingProfileId,
    selected,
    certificate,
    ipv6,
    tlsPrefix,
  );

  @override
  String toString() =>
      'RawServer('
      'id: $id, '
      'name: $name, '
      'ipAddress: $ipAddress, '
      'domain: $domain, '
      'username: $username, '
      'vpnProtocol: $vpnProtocol, '
      'dnsServers: $dnsServers, '
      'routingProfileId: $routingProfileId, '
      'selected: $selected, '
      'ipv6: $ipv6, '
      'tlsPrefix: $tlsPrefix, '
      'certificate: $certificate, '
      ')';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RawServer &&
        other.id == id &&
        other.name == name &&
        other.ipAddress == ipAddress &&
        other.domain == domain &&
        other.username == username &&
        other.password == password &&
        other.vpnProtocol == vpnProtocol &&
        listEquals(other.dnsServers, dnsServers) &&
        other.routingProfileId == routingProfileId &&
        other.selected == selected &&
        other.ipv6 == ipv6 &&
        other.tlsPrefix == tlsPrefix &&
        other.certificate == certificate;
  }

  /// Creates a copy of this server with the given fields replaced.
  ///
  /// Fields that are not provided retain their original values.
  RawServer copyWith({
    int? id,
    String? name,
    String? ipAddress,
    String? domain,
    String? username,
    String? password,
    VpnProtocol? vpnProtocol,
    List<String>? dnsServers,
    int? routingProfileId,
    bool? selected,
    bool? ipv6,
    ValueData<Certificate>? certificate,
    ValueData<String>? tlsPrefix,
  }) => RawServer(
    id: id ?? this.id,
    name: name ?? this.name,
    ipAddress: ipAddress ?? this.ipAddress,
    domain: domain ?? this.domain,
    username: username ?? this.username,
    password: password ?? this.password,
    vpnProtocol: vpnProtocol ?? this.vpnProtocol,
    dnsServers: dnsServers ?? this.dnsServers,
    routingProfileId: routingProfileId ?? this.routingProfileId,
    selected: selected ?? this.selected,
    ipv6: ipv6 ?? this.ipv6,
    certificate: certificate == null ? this.certificate : certificate.value,
    tlsPrefix: tlsPrefix == null ? this.tlsPrefix : tlsPrefix.value,
  );
}
