import SwiftUI

struct LocalDatabaseTestView: View {
    @StateObject private var recipeService = RecipeDatabaseService.shared
    @State private var testResults: [String] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Local Recipe Database Test")
                    .font(.title)
                    .fontWeight(.bold)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(testResults, id: \.self) { result in
                            Text(result)
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Button(action: runTests) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Running Tests..." : "Run Database Tests")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isLoading)

                Spacer()
            }
            .padding()
            .navigationTitle("Database Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func runTests() {
        isLoading = true
        testResults.removeAll()
        
        Task {
            await performTests()
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func performTests() async {
        await testRecipeFilesExist()
        await testLoadAllRecipes()
        await testFiltering()
        await testSearch()
        await testSpecificCuisine()
    }

    private func testRecipeFilesExist() async {
        await MainActor.run {
            testResults.append("✅ Testing recipe files existence...")
        }
        
        let files = ["indian_cuisines.json", "american_cuisines.json", "mexican_cuisines.json", 
                     "european_cuisines.json", "asian_cuisines_extended.json", 
                     "middle_eastern_african_cuisines.json", "latin_american_cuisines.json"]
        
        for file in files {
            if let path = Bundle.main.path(forResource: file.replacingOccurrences(of: ".json", with: ""), ofType: "json") {
                await MainActor.run {
                    testResults.append("✅ Found: \(file)")
                }
            } else {
                await MainActor.run {
                    testResults.append("❌ Missing: \(file)")
                }
            }
        }
    }

    private func testLoadAllRecipes() async {
        await MainActor.run {
            testResults.append("\n📊 Testing recipe loading...")
        }
        
        let recipes = recipeService.getAllRecipes()
        
        await MainActor.run {
            testResults.append("📈 Total recipes loaded: \(recipes.count)")
            
            let cuisines = Set(recipes.map { $0.cuisine.rawValue })
            testResults.append("🌍 Cuisines found: \(cuisines.count)")
            testResults.append("   - \(cuisines.joined(separator: ", "))")
            
            let difficulties = Set(recipes.map { $0.difficulty.rawValue })
            testResults.append("📊 Difficulties: \(difficulties.joined(separator: ", "))")
        }
    }

    private func testFiltering() async {
        await MainActor.run {
            testResults.append("\n🔍 Testing filtering...")
        }
        
        let vegetarianRecipes = recipeService.getRecipes(for: ["vegetarian"])
        let veganRecipes = recipeService.getRecipes(for: ["vegan"])
        let glutenFreeRecipes = recipeService.getRecipes(for: ["gluten-free"])
        
        await MainActor.run {
            testResults.append("🥬 Vegetarian recipes: \(vegetarianRecipes.count)")
            testResults.append("🌱 Vegan recipes: \(veganRecipes.count)")
            testResults.append("🌾 Gluten-free recipes: \(glutenFreeRecipes.count)")
        }
    }

    private func testSearch() async {
        await MainActor.run {
            testResults.append("\n🔎 Testing search...")
        }
        
        let chickenRecipes = recipeService.searchRecipes(query: "chicken")
        let riceRecipes = recipeService.searchRecipes(query: "rice")
        let pastaRecipes = recipeService.searchRecipes(query: "pasta")
        
        await MainActor.run {
            testResults.append("🍗 Chicken recipes: \(chickenRecipes.count)")
            testResults.append("🍚 Rice recipes: \(riceRecipes.count)")
            testResults.append("🍝 Pasta recipes: \(pastaRecipes.count)")
        }
    }

    private func testSpecificCuisine() async {
        await MainActor.run {
            testResults.append("\n🇮🇳 Testing specific cuisine...")
        }
        
        let indianRecipes = recipeService.getAllRecipes().filter { $0.cuisine == .indian }
        let italianRecipes = recipeService.getAllRecipes().filter { $0.cuisine == .italian }
        
        await MainActor.run {
            testResults.append("🇮🇳 Indian recipes: \(indianRecipes.count)")
            testResults.append("🇮🇹 Italian recipes: \(italianRecipes.count)")
            
            if let firstIndian = indianRecipes.first {
                testResults.append("   Sample: \(firstIndian.title)")
            }
            if let firstItalian = italianRecipes.first {
                testResults.append("   Sample: \(firstItalian.title)")
            }
        }
    }
}

#Preview {
    LocalDatabaseTestView()
} 