import SwiftUI

@main
struct NexusAnalyticsApp: App {
    let persistenceController = PersistenceController.shared
    
    @State private var isLoggedIn = false
    @State private var currentRole: UserRole = .admin
    @State private var currentUsername: String = ""

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                ContentView(isLoggedIn: $isLoggedIn)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environment(\.userRole, currentRole)
                    .environment(\.usernameKey, currentUsername)
            } else {
                LoginView(isLoggedIn: $isLoggedIn, currentRole: $currentRole, currentUsername: $currentUsername)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 650)
        
        MenuBarExtra("Nexus", systemImage: "waveform.path.ecg") {
            MenuBarTimerView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .menuBarExtraStyle(.window)
    }
}

// --- DÜZELTİLMİŞ TANIMLAMALAR ---

// 1. UserRole enum'ını buraya ekliyoruz ki her yerden erişilsin
enum UserRole: String {
    case admin
    case employee
}

// 2. EnvironmentKey tanımları
struct UserRoleKey: EnvironmentKey {
    static let defaultValue: UserRole = .admin
}

struct UsernameKey: EnvironmentKey {
    static let defaultValue: String = ""
}

// 3. EnvironmentValues extension
extension EnvironmentValues {
    var userRole: UserRole {
        get { self[UserRoleKey.self] }
        set { self[UserRoleKey.self] = newValue }
    }
    
    var usernameKey: String {
        get { self[UsernameKey.self] }
        set { self[UsernameKey.self] = newValue }
    }
}
