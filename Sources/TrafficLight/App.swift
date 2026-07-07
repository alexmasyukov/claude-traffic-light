import SwiftUI
import AppKit

let kPort: UInt16 = 47615

/// Оверлей-окно: не забирает фокус (иначе при клике появляется рамка/белая линия),
/// но остаётся перетаскиваемым за фон.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    let store = SessionStore()
    var window: NSWindow!
    var server: TrafficServer?
    private var tooltip: TooltipPanel?

    private let originKey = "windowOrigin"   // ключ UserDefaults для позиции

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Плавающее безрамочное окно поверх всех приложений и на всех Spaces.
        // Размер окна подгоняется под ряд светофоров (см. onSizeChange).
        let content = NSHostingView(
            rootView: RootView(
                store: store,
                onHover: { [weak self] inside, session in
                    self?.handleHover(inside, session: session)
                },
                onSizeChange: { [weak self] size in
                    self?.resizeToContent(size)
                }
            )
        )
        content.frame = NSRect(x: 0, y: 0, width: 60, height: 100)

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

        // Восстанавливаем сохранённую позицию, иначе — правый верхний угол.
        if let saved = UserDefaults.standard.string(forKey: originKey) {
            window.setFrameOrigin(NSPointFromString(saved))
        } else if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: vf.maxX - 118, y: vf.maxY - 150))
        }
        window.orderFrontRegardless()
        self.window = window

        // Сохраняем позицию при каждом перемещении окна.
        let key = originKey
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: window, queue: .main
        ) { [weak window] _ in
            guard let window else { return }
            UserDefaults.standard.set(NSStringFromPoint(window.frame.origin), forKey: key)
        }

        // HTTP-сервер: хук → обновление состояния.
        server = TrafficServer(port: kPort) { [weak self] type, sessionID, cwd in
            guard let self else { return }
            guard let event = HookEvent(rawValue: type) else { return }
            DispatchQueue.main.async {
                self.store.handle(sessionID: sessionID, event: event, cwd: cwd)
            }
        }
        if server == nil {
            FileHandle.standardError.write(Data("TrafficLight: не удалось занять порт \(kPort)\n".utf8))
        }
        server?.start()

        tooltip = TooltipPanel()
    }

    /// Показ/скрытие всплывающей подсказки при наведении на конкретный светофор.
    private func handleHover(_ inside: Bool, session: SessionState?) {
        guard let tooltip else { return }
        if inside, let session {
            // Позиционируем над курсором — корректно для любого светофора в ряду.
            let mouse = NSEvent.mouseLocation
            tooltip.show(folder: session.label, branch: session.branch, atCursor: mouse)
        } else {
            tooltip.hide()
        }
    }

    /// Подгоняем размер окна под ряд светофоров, удерживая верхний-левый угол на месте.
    private func resizeToContent(_ size: CGSize) {
        guard let window, size.width > 1, size.height > 1 else { return }
        let f = window.frame
        if abs(f.width - size.width) < 0.5 && abs(f.height - size.height) < 0.5 { return }
        let top = f.maxY                                   // фиксируем верхний край
        let origin = NSPoint(x: f.origin.x, y: top - size.height)
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}

@main
enum Main {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)   // без иконки в Dock, живёт как agent
        // delegate у NSApplication weak, но controller живёт на стеке main(),
        // а app.run() не возвращается — ссылка не пропадёт.
        let controller = AppController()
        app.delegate = controller
        app.run()
    }
}
