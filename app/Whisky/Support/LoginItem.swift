import ServiceManagement

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Registered, but the user has to allow it in System Settings › General › Login Items.
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.write("login item \(enabled ? "register" : "unregister") failed: \(error.localizedDescription)")
        }
    }

    static func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
