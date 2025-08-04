import SwiftUI

struct ContentView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                RecipeGeneratorView()
                    .tabItem { 
                        Label("Generate", systemImage: "wand.and.stars")
                    }
                    .tag(0)
                
                FavoritesView()
                    .tabItem { 
                        Label("Favorites", systemImage: "heart.fill")
                    }
                    .tag(1)
                
                SettingsView()
                    .tabItem { 
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(2)
            }
            .tint(.orange)
            .sheet(isPresented: $subscriptionManager.showPaywall) {
                PaywallView()
            }
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    ContentView()
        .environmentObject(SubscriptionManager())
        .environmentObject(RecipeManager())
} 