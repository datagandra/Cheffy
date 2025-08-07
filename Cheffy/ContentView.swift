import SwiftUI

struct ContentView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                RecipeGeneratorView()
            }
            .tabItem { 
                Label("Generate", systemImage: "wand.and.stars")
            }
            .tag(0)
            
            NavigationView {
                FavoritesView()
            }
            .tabItem { 
                Label("Favorites", systemImage: "heart.fill")
            }
            .tag(1)
            
            NavigationView {
                SettingsView()
            }
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
}

#Preview {
    ContentView()
        .environmentObject(SubscriptionManager())
        .environmentObject(RecipeManager())
} 