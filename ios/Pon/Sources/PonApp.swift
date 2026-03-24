import SwiftUI
import SwiftData

@main
struct PonApp: App {
    let container: ModelContainer
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    init() {
        let schema = Schema([Contract.self])
        let config = ModelConfiguration("PonStore", schema: schema, cloudKitDatabase: .none)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            let fallback = ModelConfiguration("PonStore", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            container = try! ModelContainer(for: schema, configurations: fallback)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionManager)
                .preferredColorScheme(.dark)
                .onAppear {
                    SeedData.insertIfEmpty(context: container.mainContext)
                }
        }
        .modelContainer(container)
    }
}
