import SwiftUI

struct RecordingIndicatorView: View {
    @State private var isAnimating: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .symbolEffect(.pulse, options: .repeating, isActive: isAnimating)
                .foregroundStyle(.white)
            
            Text("Recording...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.red.opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .onAppear {
            isAnimating = true
        }
    }
}
