import SwiftUI

struct ShoppingCartView: View {
    @EnvironmentObject var shoppingCartService: ShoppingCartService
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddItem = false
    @State private var showingClearConfirmation = false
    @State private var showingClearCheckedConfirmation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with stats
                headerSection
                
                if shoppingCartService.cartItems.isEmpty {
                    emptyCartView
                } else {
                    // Shopping list content
                    shoppingListContent
                }
            }
            .navigationTitle("Shopping Cart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Item") {
                            showingAddItem = true
                        }
                        
                        if !shoppingCartService.cartItems.isEmpty {
                            Divider()
                            
                            Button("Clear All", role: .destructive) {
                                showingClearConfirmation = true
                            }
                            
                            if shoppingCartService.checkedItems > 0 {
                                Button("Clear Checked", role: .destructive) {
                                    showingClearCheckedConfirmation = true
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
        .alert("Clear All Items", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                shoppingCartService.clearCart()
            }
        } message: {
            Text("Are you sure you want to remove all items from your shopping cart?")
        }
        .alert("Clear Checked Items", isPresented: $showingClearCheckedConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Checked", role: .destructive) {
                shoppingCartService.clearCheckedItems()
            }
        } message: {
            Text("Are you sure you want to remove all checked items from your shopping cart?")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Shopping List")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(shoppingCartService.totalItems) items • \(shoppingCartService.checkedItems) checked")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: shoppingCartService.totalItems > 0 ? Double(shoppingCartService.checkedItems) / Double(shoppingCartService.totalItems) : 0)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(shoppingCartService.checkedItems)/\(shoppingCartService.totalItems)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Empty Cart View
    private var emptyCartView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Your shopping cart is empty")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add ingredients from recipes or manually add items to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Add Item") {
                showingAddItem = true
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Shopping List Content
    private var shoppingListContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(shoppingCartService.sortedCategories, id: \.self) { category in
                    if let items = shoppingCartService.itemsByCategory[category] {
                        categorySection(category: category, items: items)
                    }
                }
            }
            .padding(.bottom, 100) // Space for bottom sheet
        }
    }
    
    // MARK: - Category Section
    private func categorySection(category: IngredientCategory, items: [ShoppingCartItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                    .font(.title3)
                
                Text(category.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(items.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Items in category
            VStack(spacing: 0) {
                ForEach(items) { item in
                    ShoppingCartItemRow(item: item)
                        .padding(.horizontal, 20)
                    
                    if item.id != items.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Shopping Cart Item Row
struct ShoppingCartItemRow: View {
    let item: ShoppingCartItem
    @EnvironmentObject var shoppingCartService: ShoppingCartService
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: {
                shoppingCartService.toggleItemChecked(item)
            }) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.isChecked ? .green : .gray)
            }
            .buttonStyle(.plain)
            
            // Item details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .strikethrough(item.isChecked)
                        .foregroundColor(item.isChecked ? .secondary : .primary)
                    
                    Spacer()
                    
                    Text("\(formatAmount(item.amount)) \(item.unit)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                if let recipe = item.addedFromRecipe {
                    Text("From: \(recipe)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            // Delete button
            Button(action: {
                shoppingCartService.removeItem(item)
            }) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", amount)
        } else {
            return String(format: "%.1f", amount)
        }
    }
}

// MARK: - Add Item View
struct AddItemView: View {
    @EnvironmentObject var shoppingCartService: ShoppingCartService
    @Environment(\.dismiss) private var dismiss
    
    @State private var itemName = ""
    @State private var amount = ""
    @State private var unit = ""
    @State private var notes = ""
    @State private var selectedCategory: IngredientCategory = .other
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Item name", text: $itemName)
                    
                    HStack {
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                        
                        TextField("Unit", text: $unit)
                    }
                    
                    TextField("Notes (optional)", text: $notes)
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(IngredientCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(category.color)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addItem()
                    }
                    .disabled(itemName.isEmpty || amount.isEmpty)
                }
            }
        }
    }
    
    private func addItem() {
        guard let amountValue = Double(amount) else { return }
        
        let newItem = ShoppingCartItem(
            name: itemName,
            amount: amountValue,
            unit: unit.isEmpty ? "piece" : unit,
            notes: notes.isEmpty ? nil : notes,
            category: selectedCategory
        )
        
        shoppingCartService.cartItems.append(newItem)
        shoppingCartService.saveCartItems()
        dismiss()
    }
}



#Preview {
    ShoppingCartView()
        .environmentObject(ShoppingCartService())
} 