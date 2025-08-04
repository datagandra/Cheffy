import SwiftUI

struct CacheManagementView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @State private var cacheStatistics: [String: Any] = [:]
    @State private var showingClearCacheAlert = false
    @State private var showingCleanExpiredAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Cache Statistics Card
                    cacheStatisticsCard
                    
                    // Recently Viewed Recipes
                    recentlyViewedSection
                    
                    // Cache Management Actions
                    cacheManagementSection
                    
                    // Cached Recipes List
                    cachedRecipesSection
                }
                .padding()
            }
            .navigationTitle("Cache Management")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadCacheStatistics()
            }
            .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearAllCache()
                }
            } message: {
                Text("This will remove all cached recipes and cooking instructions. This action cannot be undone.")
            }
            .alert("Clean Expired Cache", isPresented: $showingCleanExpiredAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clean", role: .destructive) {
                    cleanExpiredCache()
                }
            } message: {
                Text("This will remove recipes that are older than 30 days from the cache.")
            }
        }
    }
    
    // MARK: - Cache Statistics Card
    private var cacheStatisticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Cache Statistics")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Cached Recipes",
                    value: "\(cacheStatistics["totalCached"] as? Int ?? 0)",
                    icon: "doc.text.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Recently Viewed",
                    value: "\(cacheStatistics["recentlyViewed"] as? Int ?? 0)",
                    icon: "clock.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Cache Size",
                    value: String(format: "%.2f MB", cacheStatistics["cacheSizeMB"] as? Double ?? 0.0),
                    icon: "externaldrive.fill",
                    color: .purple
                )
                
                StatCard(
                    title: "Max Cache Size",
                    value: "\(cacheStatistics["maxCacheSize"] as? Int ?? 100)",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Recently Viewed Section
    private var recentlyViewedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                Text("Recently Viewed")
                    .font(.headline)
                Spacer()
            }
            
            if recipeManager.recentlyViewedRecipes.isEmpty {
                Text("No recently viewed recipes")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recipeManager.recentlyViewedRecipes.prefix(5)) { recipe in
                            RecentlyViewedCard(recipe: recipe)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Cache Management Section
    private var cacheManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.blue)
                Text("Cache Management")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                CacheActionButton(
                    title: "Clean Expired Cache",
                    subtitle: "Remove recipes older than 30 days",
                    icon: "trash.fill",
                    color: .orange
                ) {
                    showingCleanExpiredAlert = true
                }
                
                CacheActionButton(
                    title: "Clear All Cache",
                    subtitle: "Remove all cached recipes",
                    icon: "trash.circle.fill",
                    color: .red
                ) {
                    showingClearCacheAlert = true
                }
                
                CacheActionButton(
                    title: "Refresh Statistics",
                    subtitle: "Update cache information",
                    icon: "arrow.clockwise",
                    color: .blue
                ) {
                    loadCacheStatistics()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Cached Recipes Section
    private var cachedRecipesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.green)
                Text("Cached Recipes")
                    .font(.headline)
                Spacer()
                Text("\(recipeManager.cachedRecipes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if recipeManager.cachedRecipes.isEmpty {
                Text("No cached recipes")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recipeManager.cachedRecipes) { recipe in
                        CachedRecipeRow(recipe: recipe) {
                            recipeManager.removeFromCache(recipe)
                            loadCacheStatistics()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    private func loadCacheStatistics() {
        cacheStatistics = recipeManager.getCacheStatistics()
    }
    
    private func clearAllCache() {
        recipeManager.clearCache()
        loadCacheStatistics()
    }
    
    private func cleanExpiredCache() {
        recipeManager.cleanExpiredCache()
        loadCacheStatistics()
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct CacheActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentlyViewedCard: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recipe.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
            
            Text(recipe.cuisine.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 100, height: 60)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct CachedRecipeRow: View {
    let recipe: Recipe
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(recipe.cuisine.rawValue) • \(recipe.difficulty.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CacheManagementView()
        .environmentObject(RecipeManager())
} 