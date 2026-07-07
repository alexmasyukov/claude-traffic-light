import SwiftUI
import AppKit

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let store = SessionStore()
    private let ui = UIState()
    private var window: OverlayWindow!
    private var hosting: MenuHostingView!
    private var server: TrafficServer?
    private var tooltip: TooltipPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        hosting = makeHosting()
        hosting.frame = NSRect(x: 0, y: 0, width: 60, height: 100)   // стартовый; подгонится в scheduleResize

        window = OverlayWindow.make(content: hosting)
        restorePosition()
        observePosition()
        window.orderFrontRegardless()

        startServer()
        tooltip = TooltipPanel()
        scheduleResize()   // стартовый размер под заглушку
    }

    // MARK: - Сборка

    private func makeHosting() -> MenuHostingView {
        MenuHostingView(rootView: RootView(
            store: store,
            ui: ui,
            onHover: { [weak self] inside, session in self?.handleHover(inside, session: session) },
            onScaleChanged: { [weak self] in self?.scheduleResize() }
        ))
    }

    private func startServer() {
        server = TrafficServer(port: Config.port) { [weak self] type, sessionID, cwd in
            guard let self, let event = HookEvent(rawValue: type) else { return }
            DispatchQueue.main.async {
                self.store.handle(sessionID: sessionID, event: event, cwd: cwd)
                self.scheduleResize()
            }
        }
        if server == nil {
            FileHandle.standardError.write(Data("TrafficLight: не удалось занять порт \(Config.port)\n".utf8))
        }
        server?.start()
    }

    // MARK: - Позиция окна (персист в UserDefaults)

    private func restorePosition() {
        if let saved = UserDefaults.standard.string(forKey: Config.Key.windowOrigin) {
            window.setFrameOrigin(NSPointFromString(saved))
        } else if let vf = NSScreen.main?.visibleFrame {
            window.setFrameOrigin(NSPoint(x: vf.maxX - 118, y: vf.maxY - 150))  // правый верх
        }
    }

    private func observePosition() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: window, queue: .main
        ) { [weak window] _ in
            guard let window else { return }
            UserDefaults.standard.set(NSStringFromPoint(window.frame.origin), forKey: Config.Key.windowOrigin)
        }
    }

    // MARK: - Всплывающая подсказка

    private func handleHover(_ inside: Bool, session: SessionState?) {
        guard let tooltip else { return }
        if inside, let session {
            // Над курсором — корректно для любого светофора в ряду.
            tooltip.show(folder: session.label, branch: session.branch, atCursor: NSEvent.mouseLocation)
        } else {
            tooltip.hide()
        }
    }

    // MARK: - Подгонка размера окна

    /// Детерминированный размер ряда светофоров (без масштаба) — из констант Metric.
    private func baseRowSize() -> CGSize {
        let sessions = store.sessions
        var width = sessions.isEmpty ? Metric.blockWidth : 0
        for session in sessions {
            width += Metric.blockWidth
            if session.awaitingQuestion { width += Metric.questionGap + Metric.blockWidth }
        }
        width += Metric.rowGap * CGFloat(max(1, sessions.count) - 1) + 2 * Metric.rowPad
        return CGSize(width: width, height: Metric.blockHeight + 2 * Metric.rowPad)
    }

    private func scheduleResize() {
        let base = baseRowSize()
        let scale = CGFloat(ui.scale)
        resizeToContent(CGSize(width: base.width * scale, height: base.height * scale))
    }

    /// Подгоняем окно под ряд светофоров, удерживая верхний-левый угол на месте.
    private func resizeToContent(_ rawSize: CGSize) {
        guard let window, rawSize.width > 1, rawSize.height > 1 else { return }
        // +1px запас, чтобы субпиксельные расхождения при анимации не подрезали край.
        let size = CGSize(width: ceil(rawSize.width) + 1, height: ceil(rawSize.height) + 1)
        let frame = window.frame
        if abs(frame.width - size.width) < 0.5 && abs(frame.height - size.height) < 0.5 { return }

        var origin = NSPoint(x: frame.origin.x, y: frame.maxY - size.height)  // фиксируем верхний край
        // Не даём окну уехать за край экрана — иначе крайние светофоры «обрезаются».
        if let vf = (window.screen ?? NSScreen.main)?.visibleFrame {
            origin.x = min(origin.x, vf.maxX - size.width)
            origin.x = max(origin.x, vf.minX)
            origin.y = max(origin.y, vf.minY)
        }

        // Анимируем окно синхронно со scaleEffect (та же длительность), чтобы при
        // уменьшении масштаба окно не «обгоняло» контент и не резало его.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Anim.windowDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(NSRect(origin: origin, size: size), display: true)
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
