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
    let ui = UIState()
    var window: NSWindow!
    var server: TrafficServer?
    private var tooltip: TooltipPanel?
    private var hosting: NSHostingView<RootView>!

    private let originKey = "windowOrigin"   // ключ UserDefaults для позиции

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Плавающее безрамочное окно поверх всех приложений и на всех Spaces.
        // Размер окна подгоняется под ряд светофоров (см. scheduleResize).
        let content = NSHostingView(
            rootView: RootView(
                store: store,
                ui: ui,
                onHover: { [weak self] inside, session in
                    self?.handleHover(inside, session: session)
                },
                onScaleChanged: { [weak self] in
                    self?.scheduleResize()
                }
            )
        )
        self.hosting = content
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
                self.scheduleResize()
            }
        }
        if server == nil {
            FileHandle.standardError.write(Data("TrafficLight: не удалось занять порт \(kPort)\n".utf8))
        }
        server?.start()

        tooltip = TooltipPanel()
        scheduleResize()   // стартовый размер под заглушку
    }

    /// Детерминированный размер ряда светофоров (без масштаба) — из констант Metric.
    private func baseRowSize() -> CGSize {
        let sessions = store.sessions
        let count = max(1, sessions.count)
        var width: CGFloat = 0
        if sessions.isEmpty {
            width = Metric.blockWidth
        } else {
            for s in sessions {
                width += Metric.blockWidth
                if s.awaitingQuestion { width += Metric.questionGap + Metric.blockWidth }
            }
        }
        width += Metric.rowGap * CGFloat(count - 1) + 2 * Metric.rowPad
        let height = Metric.blockHeight + 2 * Metric.rowPad
        return CGSize(width: width, height: height)
    }

    /// Подгоняем окно под ряд светофоров с учётом масштаба.
    private func scheduleResize() {
        let base = baseRowSize()
        let s = CGFloat(ui.scale)
        resizeToContent(CGSize(width: base.width * s, height: base.height * s))
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
    private func resizeToContent(_ rawSize: CGSize) {
        guard let window, rawSize.width > 1, rawSize.height > 1 else { return }
        // +1px запас, чтобы субпиксельные расхождения при анимации не подрезали край.
        let size = CGSize(width: ceil(rawSize.width) + 1, height: ceil(rawSize.height) + 1)
        let f = window.frame
        if abs(f.width - size.width) < 0.5 && abs(f.height - size.height) < 0.5 { return }
        let top = f.maxY                                   // фиксируем верхний край
        var origin = NSPoint(x: f.origin.x, y: top - size.height)
        // Не даём окну уехать за край экрана — иначе крайние светофоры «обрезаются».
        if let vf = (window.screen ?? NSScreen.main)?.visibleFrame {
            if origin.x + size.width > vf.maxX { origin.x = vf.maxX - size.width }
            if origin.x < vf.minX { origin.x = vf.minX }
            if origin.y < vf.minY { origin.y = vf.minY }
        }
        let newFrame = NSRect(origin: origin, size: size)
        // Анимируем окно синхронно с scaleEffect (та же длительность), чтобы при
        // уменьшении масштаба окно не «обгоняло» контент и не резало его.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(newFrame, display: true)
        }
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
