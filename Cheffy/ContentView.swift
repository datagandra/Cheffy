import SwiftUI

struct ContentView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                RecipeDiscoveryView()
                    .tabItem { 
                        Label("Discover", systemImage: "magnifyingglass")
                    }
                    .tag(0)
                
                RecipeGeneratorView()
                    .tabItem { 
                        Label("Generate", systemImage: "wand.and.stars")
                    }
                    .tag(1)
                
                FavoritesView()
                    .tabItem { 
                        Label("Favorites", systemImage: "heart.fill")
                    }
                    .tag(2)
                
                SettingsView()
                    .tabItem { 
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(3)
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