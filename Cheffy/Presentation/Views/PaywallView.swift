import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Upgrade to PRO")
                    .font(.largeTitle)
                    .padding()
                
                Text("Unlock unlimited recipe generations and premium features")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("PRO Subscription")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
} 