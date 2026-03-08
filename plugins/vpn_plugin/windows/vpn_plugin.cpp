#include "vpn_plugin.h"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <thread>

// vpn_easy C API — provided by vpn_easy.dll built from TrustTunnelClient.
#include "vpn_easy.h"

using flutter::EncodableValue;

namespace vpn_plugin {

// ── MockStorage ───────────────────────────────────────────────────────────────

MockStorage::MockStorage() { SetupMockData(); }

void MockStorage::SetupMockData() {
  routing_profiles_ = {
      RoutingProfile{1, "Default Profile", RoutingMode::kVpn,
                     {"192.168.1.0/24", "10.0.0.0/8"}, {"*"}},
      RoutingProfile{2, "Work Profile", RoutingMode::kBypass,
                     {"company.com", "*.internal"}, {"social.com", "*.entertainment"}},
  };

  servers_ = {
      Server{1, "192.168.1.100", "vpn1.example.com", "user1", "password1",
             {"8.8.8.8", "8.8.4.4"}, VpnProtocol::kQuic, 1},
      Server{2, "10.0.0.50", "vpn2.example.com", "user2", "password2",
             {"1.1.1.1", "1.0.0.1"}, VpnProtocol::kHttp2, 2},
  };

  selected_server_id_ = 1;
  excluded_routes_    = "192.168.0.0/16,10.0.0.0/8";

  requests_ = {
      VpnRequest{"2024-08-22T12:00:00Z", "HTTPS", RoutingMode::kVpn, "192.168.1.10",
                 "8.8.8.8", "54321", "443", "google.com"}};
}

// ── VpnEventStreamHandler ─────────────────────────────────────────────────────

VpnEventStreamHandler::VpnEventStreamHandler(MockStorage* storage)
    : storage_(storage) {}

void VpnEventStreamHandler::EmitState(VpnManagerState state) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (!sink_) return;
  sink_->Success(EncodableValue(static_cast<int64_t>(state)));
}

std::unique_ptr<flutter::StreamHandlerError<EncodableValue>>
VpnEventStreamHandler::OnListenInternal(
    const EncodableValue* /*arguments*/,
    std::unique_ptr<flutter::EventSink<EncodableValue>>&& events) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    sink_ = std::move(events);
  }
  EmitState(storage_->CurrentVpnState());
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<EncodableValue>>
VpnEventStreamHandler::OnCancelInternal(const EncodableValue* /*arguments*/) {
  std::lock_guard<std::mutex> lock(mutex_);
  sink_.reset();
  return nullptr;
}

// ── IVpnManagerImpl — real vpn_easy bridge ───────────────────────────────────

IVpnManagerImpl::IVpnManagerImpl(MockStorage* storage, VpnEventStreamHandler* handler,
                                 HWND msg_hwnd)
    : storage_(storage), handler_(handler), msg_hwnd_(msg_hwnd) {}

IVpnManagerImpl::~IVpnManagerImpl() {
  // Ensure the engine is stopped if the plugin is torn down.
  vpn_easy_stop();
}

// Static callback — invoked from vpn_easy's internal thread.
// Maps VPN_SS_* integer values to VpnManagerState and forwards to Flutter.
void IVpnManagerImpl::OnVpnStateChanged(void* arg, int new_state) {
  auto* self = static_cast<IVpnManagerImpl*>(arg);

  VpnManagerState mapped;
  switch (new_state) {
    case 0: mapped = VpnManagerState::kDisconnected;       break;
    case 1: mapped = VpnManagerState::kConnecting;         break;
    case 2: mapped = VpnManagerState::kConnected;          break;
    case 3: mapped = VpnManagerState::kWaitingForRecovery; break;
    case 4: mapped = VpnManagerState::kRecovering;         break;
    case 5: mapped = VpnManagerState::kWaitingForNetwork;  break;
    default: mapped = VpnManagerState::kDisconnected;      break;
  }

  self->storage_->CurrentVpnState() = mapped;

  // Marshal to the UI thread via a message-only window.
  ::PostMessage(self->msg_hwnd_, WM_VPN_STATE, static_cast<WPARAM>(mapped), 0);
}

std::optional<FlutterError> IVpnManagerImpl::Start(const std::string& /*server_name*/,
                                                    const std::string& config) {
  storage_->CurrentVpnState() = VpnManagerState::kConnecting;
  ::PostMessage(msg_hwnd_, WM_VPN_STATE,
                static_cast<WPARAM>(VpnManagerState::kConnecting), 0);

  // Debug: write the TOML config to a file for inspection.
  {
    wchar_t path[MAX_PATH];
    ::GetTempPathW(MAX_PATH, path);
    std::wstring log_path = std::wstring(path) + L"vpn_easy_config.toml";
    if (FILE* f = ::_wfopen(log_path.c_str(), L"w")) {
      ::fwrite(config.c_str(), 1, config.size(), f);
      ::fclose(f);
    }
  }

  vpn_easy_start(config.c_str(), &IVpnManagerImpl::OnVpnStateChanged, this);
  return std::nullopt;
}

std::optional<FlutterError> IVpnManagerImpl::Stop() {
  vpn_easy_stop();
  storage_->CurrentVpnState() = VpnManagerState::kDisconnected;
  ::PostMessage(msg_hwnd_, WM_VPN_STATE,
                static_cast<WPARAM>(VpnManagerState::kDisconnected), 0);
  return std::nullopt;
}

std::optional<FlutterError> IVpnManagerImpl::UpdateConfiguration(
    const std::string* /*server_name*/, const std::string* /*config*/) {
  return std::nullopt;
}

ErrorOr<VpnManagerState> IVpnManagerImpl::GetCurrentState() {
  return storage_->CurrentVpnState();
}

// ── ServersManagerImpl ────────────────────────────────────────────────────────

AddNewServerResult ServersManagerImpl::AddNewServer(const std::string& /*name*/,
                                                    const std::string& ip,
                                                    const std::string& domain,
                                                    const std::string& user,
                                                    const std::string& pass,
                                                    VpnProtocol proto,
                                                    int64_t routing_profile_id,
                                                    const std::string& dns_csv) {
  if (ip.empty() || !IsValidIp(ip)) return AddNewServerResult::kIpAddressIncorrect;
  if (domain.empty())               return AddNewServerResult::kDomainIncorrect;
  if (user.empty())                 return AddNewServerResult::kUsernameIncorrect;
  if (pass.empty())                 return AddNewServerResult::kPasswordIncorrect;

  auto dns = SplitAndTrim(dns_csv, ',');
  if (dns.empty()) return AddNewServerResult::kDnsServersIncorrect;

  int64_t new_id = 1;
  for (const auto& s : storage_->AllServers()) new_id = std::max(new_id, s.id + 1);

  storage_->AllServers().push_back(
      Server{new_id, ip, domain, user, pass, dns, proto, routing_profile_id});
  return AddNewServerResult::kOk;
}

AddNewServerResult ServersManagerImpl::SetNewServer(int64_t id, const std::string& /*name*/,
                                                    const std::string& ip,
                                                    const std::string& domain,
                                                    const std::string& user,
                                                    const std::string& pass,
                                                    VpnProtocol proto,
                                                    int64_t routing_profile_id,
                                                    const std::string& dns_csv) {
  if (ip.empty() || !IsValidIp(ip)) return AddNewServerResult::kIpAddressIncorrect;
  if (domain.empty())               return AddNewServerResult::kDomainIncorrect;
  if (user.empty())                 return AddNewServerResult::kUsernameIncorrect;
  if (pass.empty())                 return AddNewServerResult::kPasswordIncorrect;

  auto dns = SplitAndTrim(dns_csv, ',');
  if (dns.empty()) return AddNewServerResult::kDnsServersIncorrect;

  auto& all = storage_->AllServers();
  for (auto& s : all) {
    if (s.id == id) {
      s = Server{id, ip, domain, user, pass, dns, proto, routing_profile_id};
      break;
    }
  }
  return AddNewServerResult::kOk;
}

void ServersManagerImpl::RemoveServer(int64_t id) {
  auto& all = storage_->AllServers();
  all.erase(
      std::remove_if(all.begin(), all.end(), [&](const Server& s) { return s.id == id; }),
      all.end());
  if (storage_->CurrentSelectedServerId().has_value() &&
      storage_->CurrentSelectedServerId().value() == id) {
    storage_->CurrentSelectedServerId().reset();
  }
}

bool ServersManagerImpl::IsValidIp(const std::string& ip) {
  auto parts = SplitAndTrim(ip, '.');
  if (parts.size() != 4) return false;
  for (auto& p : parts) {
    try {
      int v = std::stoi(p);
      if (v < 0 || v > 255) return false;
    } catch (...) { return false; }
  }
  return true;
}

std::vector<std::string> ServersManagerImpl::SplitAndTrim(const std::string& s, char delim) {
  std::vector<std::string> out;
  std::string cur;
  for (char c : s) {
    if (c == delim) {
      Trim(cur);
      if (!cur.empty()) out.push_back(cur);
      cur.clear();
    } else {
      cur.push_back(c);
    }
  }
  Trim(cur);
  if (!cur.empty()) out.push_back(cur);
  return out;
}

void ServersManagerImpl::Trim(std::string& str) {
  auto not_space = [](int ch) { return !std::isspace(ch); };
  str.erase(str.begin(), std::find_if(str.begin(), str.end(), not_space));
  str.erase(std::find_if(str.rbegin(), str.rend(), not_space).base(), str.end());
}

// ── RoutingProfilesManagerImpl ────────────────────────────────────────────────

void RoutingProfilesManagerImpl::AddNewProfile() {
  int64_t new_id = 1;
  for (const auto& p : storage_->AllRoutingProfiles()) new_id = std::max(new_id, p.id + 1);
  storage_->AllRoutingProfiles().push_back(
      RoutingProfile{new_id, "Profile " + std::to_string(new_id), RoutingMode::kVpn, {}, {}});
}

void RoutingProfilesManagerImpl::SetDefaultRoutingMode(int64_t id, RoutingMode mode) {
  for (auto& p : storage_->AllRoutingProfiles()) {
    if (p.id == id) { p.default_mode = mode; break; }
  }
}

void RoutingProfilesManagerImpl::SetProfileName(int64_t id, const std::string& name) {
  for (auto& p : storage_->AllRoutingProfiles()) {
    if (p.id == id) { p.name = name; break; }
  }
}

void RoutingProfilesManagerImpl::SetRules(int64_t id, RoutingMode mode,
                                          const std::string& rules) {
  auto arr = ServersManagerImpl::SplitAndTrim(rules, '\n');
  for (auto& p : storage_->AllRoutingProfiles()) {
    if (p.id == id) {
      if (mode == RoutingMode::kBypass) p.bypass_rules = arr; else p.vpn_rules = arr;
      break;
    }
  }
}

void RoutingProfilesManagerImpl::RemoveAllRules(int64_t id) {
  for (auto& p : storage_->AllRoutingProfiles()) {
    if (p.id == id) { p.bypass_rules.clear(); p.vpn_rules.clear(); break; }
  }
}

// ── VpnPlugin ─────────────────────────────────────────────────────────────────

// WndProc for the message-only window that marshals VPN state to the UI thread.
static LRESULT CALLBACK VpnMsgWndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
  if (msg == WM_VPN_STATE) {
    auto* handler = reinterpret_cast<VpnEventStreamHandler*>(
        ::GetWindowLongPtr(hwnd, GWLP_USERDATA));
    if (handler) {
      handler->EmitState(static_cast<VpnManagerState>(wp));
    }
    return 0;
  }
  return ::DefWindowProc(hwnd, msg, wp, lp);
}

void VpnPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto messenger = registrar->messenger();

  // Create a message-only window to marshal vpn_easy callbacks onto the UI thread.
  static const wchar_t kWndClass[] = L"VpnPluginMsgWnd";
  WNDCLASSW wc = {};
  wc.lpfnWndProc   = VpnMsgWndProc;
  wc.hInstance     = ::GetModuleHandle(nullptr);
  wc.lpszClassName = kWndClass;
  ::RegisterClassW(&wc);  // Ignores ERROR_CLASS_ALREADY_EXISTS on re-register.
  HWND msg_hwnd = ::CreateWindowExW(0, kWndClass, nullptr, 0,
                                    0, 0, 0, 0, HWND_MESSAGE, nullptr,
                                    wc.hInstance, nullptr);

  auto storage = std::make_shared<MockStorage>();
  auto handler = std::make_unique<VpnEventStreamHandler>(storage.get());
  auto* handler_raw = handler.get();

  // Store handler pointer in the window so VpnMsgWndProc can reach it.
  ::SetWindowLongPtr(msg_hwnd, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(handler_raw));

  auto event_channel = std::make_unique<flutter::EventChannel<EncodableValue>>(
      messenger, "vpn_plugin_event_channel", &flutter::StandardMethodCodec::GetInstance());
  // Transfer ownership of handler to the event channel.
  event_channel->SetStreamHandler(std::move(handler));

  auto vpn_manager = std::make_unique<IVpnManagerImpl>(storage.get(), handler_raw, msg_hwnd);
  auto storage_manager = std::make_unique<StorageManagerImpl>(storage.get());
  auto servers_manager = std::make_unique<ServersManagerImpl>(storage.get());
  auto routing_manager = std::make_unique<RoutingProfilesManagerImpl>(storage.get());

  IVpnManager::SetUp(messenger, vpn_manager.get());

  static IDeepLinkImpl deep_link_impl;
  IDeepLink::SetUp(messenger, &deep_link_impl);

  registrar->AddPlugin(std::make_unique<VpnPlugin>(
      msg_hwnd, std::move(event_channel), storage,
      std::move(vpn_manager), std::move(storage_manager),
      std::move(servers_manager), std::move(routing_manager)));
}

VpnPlugin::VpnPlugin(
    HWND msg_hwnd,
    std::unique_ptr<flutter::EventChannel<EncodableValue>> event_channel,
    std::shared_ptr<MockStorage>                storage,
    std::unique_ptr<IVpnManagerImpl>            vpn_manager,
    std::unique_ptr<StorageManagerImpl>         storage_manager,
    std::unique_ptr<ServersManagerImpl>         servers_manager,
    std::unique_ptr<RoutingProfilesManagerImpl> routing_manager)
    : msg_hwnd_(msg_hwnd),
      event_channel_(std::move(event_channel)),
      storage_(std::move(storage)),
      vpn_manager_(std::move(vpn_manager)),
      storage_manager_(std::move(storage_manager)),
      servers_manager_(std::move(servers_manager)),
      routing_manager_(std::move(routing_manager)) {}

VpnPlugin::~VpnPlugin() {
  if (msg_hwnd_) {
    ::SetWindowLongPtr(msg_hwnd_, GWLP_USERDATA, 0);
    ::DestroyWindow(msg_hwnd_);
  }
}

}  // namespace vpn_plugin
