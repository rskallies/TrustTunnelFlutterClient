#include "include/vpn_plugin/vpn_plugin_c_api.h"
#include "include/vpn_plugin/vpn_plugin.h"

#include <flutter/plugin_registrar_windows.h>

#include "vpn_plugin.h"

static void RegisterImpl(FlutterDesktopPluginRegistrarRef registrar) {
  vpn_plugin::VpnPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

void VpnPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  RegisterImpl(registrar);
}

void VpnPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  RegisterImpl(registrar);
}
