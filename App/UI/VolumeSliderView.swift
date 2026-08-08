import SwiftUI

struct VolumeSliderView: View {
    let volumeLevel: Int?
    let onChange: (Int) -> Void

    @State private var sliderValue: Double = 0
    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Slider(value: $sliderValue, in: 0...100) { editing in
                isEditing = editing
                if !editing {
                    onChange(Int(sliderValue.rounded()))
                }
            }

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .disabled(volumeLevel == nil)
        .onAppear {
            sliderValue = Double(volumeLevel ?? 0)
        }
        // Live von außen geänderte Lautstärke übernehmen, aber nicht während
        // der Nutzer selbst gerade zieht (sonst "springt" der Regler).
        .onChange(of: volumeLevel) { _, newValue in
            guard !isEditing, let newValue else { return }
            sliderValue = Double(newValue)
        }
    }
}
