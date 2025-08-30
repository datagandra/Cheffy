import SwiftUI

// MARK: - Inline Shopping Cart View
struct InlineShoppingCartView: View {
    @EnvironmentObject var shoppingCartService: ShoppingCartService
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddItem = false
    @State private var showingClearConfirmation = false
    @State private var showingClearCheckedConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Content
                if shoppingCartService.cartItems.isEmpty {
                    emptyCartView
                } else {
                    shoppingListContent
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Item") {
                        showingAddItem = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            InlineAddItemView()
        }
        .alert("Clear Shopping List", isPresented: $showingClearConfirmation) {
            Button("Clear All", role: .destructive) {
                shoppingCartService.clearCart()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to clear all items from your shopping list?")
        }
        .alert("Remove Checked Items", isPresented: $showingClearCheckedConfirmation) {
            Button("Remove Checked", role: .destructive) {
                shoppingCartService.clearCheckedItems()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove all checked items?")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(shoppingCartService.cartItems.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Total Items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(shoppingCartService.checkedItems)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Checked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: { showingClearConfirmation = true }) {
                    Label("Clear All", systemImage: "trash")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Button(action: { showingClearCheckedConfirmation = true }) {
                    Label("Remove Checked", systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - Empty Cart View
    private var emptyCartView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Shopping List is Empty")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Add ingredients from recipes or manually add items to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Shopping List Content
    private var shoppingListContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(IngredientCategory.allCases, id: \.self) { category in
                    let categoryItems = shoppingCartService.cartItems.filter { $0.category == category }
                    if !categoryItems.isEmpty {
                        categorySection(category: category, items: categoryItems)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Category Section
    private func categorySection(category: IngredientCategory, items: [ShoppingCartItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                    .font(.title3)
                
                Text(category.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(items.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(category.color.opacity(0.2))
                    .foregroundColor(category.color)
                    .cornerRadius(8)
            }
            
            VStack(spacing: 8) {
                ForEach(items) { item in
                    InlineShoppingCartItemRow(item: item)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Inline Shopping Cart Item Row
struct InlineShoppingCartItemRow: View {
    let item: ShoppingCartItem
    @EnvironmentObject var shoppingCartService: ShoppingCartService
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: {
                shoppingCartService.toggleItemChecked(item)
            }) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isChecked ? .green : .gray)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Item Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(item.isChecked)
                        .foregroundColor(item.isChecked ? .secondary : .primary)
                    
                    Spacer()
                    
                    Text("\(formatAmount(item.amount)) \(item.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                if let recipeName = item.addedFromRecipe {
                    Text("From: \(recipeName)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Remove Button
            Button(action: {
                shoppingCartService.removeItem(item)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .opacity(item.isChecked ? 0.6 : 1.0)
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", amount)
        } else {
            return String(format: "%.1f", amount)
        }
    }
}

// MARK: - Inline Add Item View
struct InlineAddItemView: View {
    @EnvironmentObject var shoppingCartService: ShoppingCartService
    @Environment(\.dismiss) private var dismiss
    @State private var itemName = ""
    @State private var amount = ""
    @State private var unit = ""
    @State private var notes = ""
    @State private var selectedCategory: IngredientCategory = .other
    
    var body: some View {
        NavigationView {
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
        guard let amountValue = Double(amount), !itemName.isEmpty else { return }
        
        let newItem = ShoppingCartItem(
            name: itemName,
            amount: amountValue,
            unit: unit.isEmpty ? "piece" : unit,
            notes: notes.isEmpty ? nil : notes,
            category: selectedCategory,
            addedFromRecipe: nil
        )
        
        shoppingCartService.addItem(newItem)
        dismiss()
    }
} 