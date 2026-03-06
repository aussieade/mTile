import SwiftUI

/// Main overlay view combining title bar, grid, and preset bar.
struct OverlayView: View {
    let title: String
    let presets: [GridSize]
    @Binding var gridSize: GridSize
    @Binding var selection: GridSelection?
    @ObservedObject var interactionState: GridInteractionState

    let onSelectionComplete: ((GridSelection) -> Void)?
    var onHoverChanged: ((GridOffset?) -> Void)?
    let onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            // Title Bar
            titleBar

            // Grid
            GridView(
                gridSize: gridSize,
                selection: $selection,
                onHoverChanged: onHoverChanged,
                onSelectionComplete: onSelectionComplete,
                interactionState: interactionState
            )
            .frame(height: 150)

            // Preset Bar
            presetBar
        }
        .padding(12)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )
        .frame(width: 280)
    }

    private var titleBar: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text("\(gridSize.cols)x\(gridSize.rows)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)

            Button {
                onClose?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
        }
    }

    private var presetBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(presets.enumerated()), id: \.offset) { index, preset in
                Button {
                    gridSize = preset
                    selection = nil
                    interactionState.anchor = nil
                } label: {
                    Text("\(preset.cols)x\(preset.rows)")
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.bordered)
                .tint(gridSize == preset ? .accentColor : nil)
            }

            Spacer()
        }
    }

}

/// NSVisualEffectView wrapper for SwiftUI.
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
