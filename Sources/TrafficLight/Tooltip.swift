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

    /// Показать над светофором: панель садится нижним краем на `bottomY`
    /// (экранные координаты, y вверх), по центру относительно `centerX`.
    func showAbove(folder: String, branch: String?, centerX: CGFloat, bottomY: CGFloat) {
        model.folder = folder
        model.branch = branch
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        panel.setContentSize(size)

        let x = centerX - size.width / 2
        panel.setFrameOrigin(NSPoint(x: x, y: bottomY))
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
                    .fill(Palette.tooltipBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Palette.tooltipBorder, lineWidth: 1)
            )
            .padding(4)
    }
}
