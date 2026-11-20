#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <powrprof.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

DWORD RequestPowerAction(bool sleep) {
  TOKEN_PRIVILEGES privileges{};
  privileges.PrivilegeCount = 1;
  privileges.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
  if (!LookupPrivilegeValue(nullptr, SE_SHUTDOWN_NAME,
                            &privileges.Privileges[0].Luid)) {
    return GetLastError();
  }

  HANDLE token;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
                        &token)) {
    return GetLastError();
  }

  TOKEN_PRIVILEGES previous{};
  DWORD previous_size = 0;
  AdjustTokenPrivileges(token, FALSE, &privileges, sizeof(previous), &previous,
                        &previous_size);
  // Windows also reports an unassigned privilege through GetLastError.
  DWORD error = GetLastError();
  if (error == ERROR_SUCCESS) {
    const bool accepted = sleep
        ? SetSuspendState(FALSE, FALSE, FALSE) != FALSE
        : ExitWindowsEx(EWX_POWEROFF, SHTDN_REASON_MAJOR_APPLICATION |
                                        SHTDN_REASON_FLAG_PLANNED) != FALSE;
    if (!accepted) error = GetLastError();
    AdjustTokenPrivileges(token, FALSE, &previous, 0, nullptr, nullptr);
  }
  CloseHandle(token);
  return error;
}

void RegisterPowerChannel(flutter::BinaryMessenger* messenger) {
  flutter::MethodChannel<flutter::EncodableValue> channel(
      messenger, "kikoeta_transl/power", &flutter::StandardMethodCodec::GetInstance());
  channel.SetMethodCallHandler([](const auto& call, auto result) {
    const auto& method = call.method_name();
    DWORD error = ERROR_SUCCESS;
    if (method == "lock") {
      if (!LockWorkStation()) error = GetLastError();
    } else if (method == "sleep" || method == "shutdown") {
      error = RequestPowerAction(method == "sleep");
    } else {
      result->NotImplemented();
      return;
    }
    if (error == ERROR_SUCCESS) {
      result->Success();
    } else {
      result->Error("windows_power_action_failed", "Win32 " + std::to_string(error));
    }
  });
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterPowerChannel(flutter_controller_->engine()->messenger());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
