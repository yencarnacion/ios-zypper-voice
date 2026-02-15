import SwiftUI

@main
struct ZypperVoiceApp: App {
    @StateObject private var permissions = PermissionsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(permissions)
                .task {
                    permissions.refresh()
                }
        }
    }
}
