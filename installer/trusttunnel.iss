#define AppName "TrustTunnel"
#define AppVersion "1.0.0"
#define AppPublisher "TrustTunnel"
#define AppExeName "vpn.exe"
#define AppIconName "app_icon.ico"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..\installer_output
OutputBaseFilename=TrustTunnel-Setup-x64
SetupIconFile={#BuildDir}\data\flutter_assets\assets\images\tray\tray_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#AppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Start TrustTunnel automatically at login"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
; Main executable
Source: "{#BuildDir}\{#AppExeName}";         DestDir: "{app}"; Flags: ignoreversion
; DLLs
Source: "{#BuildDir}\flutter_windows.dll";              DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\vpn_easy.dll";                     DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\vpn_plugin_plugin.dll";            DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\wintun.dll";                       DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\sqlite3.dll";                      DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\sqlite3_flutter_libs_plugin.dll";  DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\tray_manager_plugin.dll";          DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\url_launcher_windows_plugin.dll";  DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\window_manager_plugin.dll";        DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\screen_retriever_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
; Data directory (Flutter assets, icudtl.dat, app.so)
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; MSVC runtime redistributable
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#AppName}";          Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";    Filename: "{app}\{#AppExeName}"; Tasks: desktopicon
Name: "{autostartup}\{#AppName}";    Filename: "{app}\{#AppExeName}"; Tasks: startupicon

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing MSVC runtime..."; Flags: waituntilterminated
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
