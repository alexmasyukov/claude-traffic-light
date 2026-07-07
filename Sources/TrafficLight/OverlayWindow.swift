import SwiftUI
import AppKit

/// Оверлей-окно: не забирает фокус (иначе при клике появляется рамка/белая линия),
/// но остаётся перетаскиваемым за фон.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Плавающее безрамочное окно поверх всех приложений и на всех Spaces.
    static func make(content: NSView) -> OverlayWindow {
        let window = OverlayWindow(
            contentRect: content.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = content
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar                       // выше обычных окон
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true       // таскать мышью
        window.ignoresMouseEvents = false
        return window
    }
}

/// Hosting-view с контекстным меню по правому клику (пункт «Выход»).
final class MenuHostingView: NSHostingView<RootView> {
    required init(rootView: RootView) { super.init(rootView: rootView) }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let quit = NSMenuItem(title: "Выход",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}
