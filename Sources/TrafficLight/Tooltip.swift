import SwiftUI
import AppKit

/// Всплывающая подсказка (папка · ветка) — отдельная лёгкая панель, шрифт 16.
@MainActor
final class TooltipPanel {
    private let panel: NSPanel
    private let host: NSHostingView<TooltipView>
    private let model = TooltipModel()

    init() {
        host = NSHostingView(rootView: TooltipView(model: model))
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu                       // поверх светофора
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true                // не мешает мыши
        panel.hidesOnDeactivate = false
    }

    func show(folder: String, branch: String?, atCursor cursor: NSPoint) {
        model.folder = folder
        model.branch = branch
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        panel.setContentSize(size)

        // Над курсором, по центру по горизонтали.
        let x = cursor.x - size.width / 2
        let y = cursor.y + 22
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}

@MainActor
final class TooltipModel: ObservableObject {
    @Published var folder: String = ""
    @Published var branch: String?
}

struct TooltipView: View {
    @ObservedObject var model: TooltipModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.folder)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            if let branch = model.branch, !branch.isEmpty {
                Text(branch)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.black.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .padding(4)
    }
}
