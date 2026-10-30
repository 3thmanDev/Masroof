import SwiftUI

@main
struct MasroofApp: App {
    @StateObject private var store = BudgetStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .appEnvironment()
        }
    }
}
