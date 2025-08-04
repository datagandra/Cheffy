import SwiftUI

// MARK: - BadgeView
struct BadgeView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

// MARK: - TimeCard
struct TimeCard: View {
    let title: String
    let time: String
    let icon: String
    var isHighlighted: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isHighlighted ? .blue : .secondary)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(time)
                    .font(.subheadline)
                    .fontWeight(isHighlighted ? .bold : .medium)
                    .foregroundColor(isHighlighted ? .blue : .primary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - SectionHeader
struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var isExpanded: Bool
    
    var body: some View {
        Button(action: { 
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - IngredientRow
struct IngredientRow: View {
    let ingredient: Ingredient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(ingredient.amount, specifier: "%.1f") \(ingredient.unit)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Text(ingredient.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                    
                    if let notes = ingredient.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BadgeView(text: "French", color: .orange)
        BadgeView(text: "Medium", color: .blue)
        TimeCard(title: "Prep", time: "30m", icon: "clock", isHighlighted: true)
        TimeCard(title: "Cook", time: "45m", icon: "timer")
    }
    .padding()
} 