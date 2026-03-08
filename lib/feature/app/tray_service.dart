import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';

/// Callback invoked when the user clicks Connect/Disconnect in the tray menu.
typedef TrayVpnToggleCallback = void Function();

/// Manages the system tray icon and context menu.
///
/// Only active on Windows (and macOS/Linux desktop). Safe to instantiate on
/// all platforms — all methods are no-ops on unsupported platforms.
class TrayService with TrayListener {
  TrayService._();

  static final TrayService instance = TrayService._();

  /// Must be called once, after [WidgetsFlutterBinding.ensureInitialized].
  static bool get _isSupported =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  VpnState _vpnState = VpnState.disconnected;
  TrayVpnToggleCallback? _onToggle;
  VoidCallback? _onShow;
  VoidCallback? _onQuit;

  /// Replaces the toggle callback at runtime (e.g. after the widget tree is ready).
  void setToggleCallback(TrayVpnToggleCallback callback) {
    _onToggle = callback;
  }

  Future<void> init({
    required TrayVpnToggleCallback onToggle,
    required VoidCallback onShow,
    required VoidCallback onQuit,
  }) async {
    if (!_isSupported) return;

    _onToggle = onToggle;
    _onShow = onShow;
    _onQuit = onQuit;

    trayManager.addListener(this);
    await _applyIcon();
    await _applyMenu();
  }

  Future<void> dispose() async {
    if (!_isSupported) return;
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  Future<void> updateState(VpnState state) async {
    if (!_isSupported) return;
    if (_vpnState == state) return;
    _vpnState = state;
    await _applyIcon();
    await _applyMenu();
  }

  // ── Private ──────────────────────────────────────────────────────────────

  Future<void> _applyIcon() async {
    // Windows requires .ico format; macOS/Linux use .png.
    final ext = Platform.isWindows ? 'ico' : 'png';
    final icon = _vpnState == VpnState.connected
        ? 'assets/images/tray/tray_icon_connected.$ext'
        : 'assets/images/tray/tray_icon.$ext';
    await trayManager.setIcon(icon);
    await trayManager.setToolTip(_tooltip);
  }

  Future<void> _applyMenu() async {
    await trayManager.setContextMenu(Menu(items: _menuItems));
  }

  String get _tooltip {
    return switch (_vpnState) {
      VpnState.connected => 'TrustTunnel — Connected',
      VpnState.connecting => 'TrustTunnel — Connecting…',
      VpnState.recovering => 'TrustTunnel — Reconnecting…',
      VpnState.waitingForRecovery => 'TrustTunnel — Waiting to reconnect…',
      VpnState.waitingForNetwork => 'TrustTunnel — Waiting for network…',
      VpnState.disconnected => 'TrustTunnel — Disconnected',
    };
  }

  List<MenuItem> get _menuItems {
    final isConnected = _vpnState == VpnState.connected;
    final isBusy = _vpnState == VpnState.connecting ||
        _vpnState == VpnState.recovering ||
        _vpnState == VpnState.waitingForRecovery ||
        _vpnState == VpnState.waitingForNetwork;

    return [
      MenuItem(
        key: 'show',
        label: 'Show TrustTunnel',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'toggle',
        label: isConnected ? 'Disconnect' : 'Connect',
        disabled: isBusy,
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'quit',
        label: 'Quit',
      ),
    ];
  }

  // ── TrayListener ─────────────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() => _onShow?.call();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _onShow?.call();
      case 'toggle':
        _onToggle?.call();
      case 'quit':
        _onQuit?.call();
    }
  }
}
