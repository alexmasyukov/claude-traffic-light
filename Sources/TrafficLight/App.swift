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
        hosting.onCycleShape = { [weak self] in
            guard let self else { return }
            self.ui.cycleShape()
            self.scheduleResize()
        }
        hosting.labelsShown = { [weak self] in self?.ui.showLabels ?? false }
        hosting.onToggleLabels = { [weak self] in
            guard let self else { return }
            self.ui.toggleLabels()
            self.scheduleResize()
        }

        window = OverlayWindow.make(content: hosting)
        restorePosition()
        observePosition()

        startServer()
        tooltip = TooltipPanel()
        scheduleResize()   // нет сессий на старте → окно остаётся скрытым
    }

    // MARK: - Сборка

    private func makeHosting() -> MenuHostingView {
        MenuHostingView(rootView: RootView(
            store: store,
            ui: ui,
            onHover: { [weak self] inside, session in self?.handleHover(inside, session: session) },
            onScaleChanged: { [weak self] in self?.scheduleResize() },
            onActivate: { [weak self] session in self?.activateOwner(session) }
        ))
    }

    private func startServer() {
        server = TrafficServer(port: Config.port) { [weak self] type, sessionID, cwd, app in
            guard let self, let event = HookEvent(rawValue: type) else { return }
            DispatchQueue.main.async {
                self.store.handle(sessionID: sessionID, event: event, cwd: cwd, app: app)
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

    /// Клик по светофору — вывести на передний план приложение, где запущен его Claude Code.
    /// Фоновому .accessory-приложению macOS не даёт активировать чужое окно
    /// (ни NSRunningApplication.activate, ни NSWorkspace — только дёргают фокус),
    /// поэтому шлём Apple Event `activate` — он пробивает. Требует права «Автоматизация»
    /// (запрос появится при первом клике; в Info.plist есть NSAppleEventsUsageDescription).
    private func activateOwner(_ session: SessionState) {
        guard let bundleID = session.ownerBundleID, !bundleID.isEmpty else { return }
        // NSAppleScript не потокобезопасен — выполняем на main (тап и так на main).
        // reopen = клик по иконке в Dock: разворачивает свёрнутое окно; activate — вперёд.
        let source = """
        tell application id "\(bundleID)"
            reopen
            activate
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            FileHandle.standardError.write(Data("TrafficLight: activate \(bundleID) → \(error)\n".utf8))
        }
    }

    private func handleHover(_ inside: Bool, session: SessionState?) {
        guard let tooltip, let window else { return }
        if inside, let session {
            // Всегда над светофором (по верхней кромке окна), не перекрывая его;
            // по горизонтали — над курсором (над тем светофором, на который навели).
            let centerX = NSEvent.mouseLocation.x
            let bottomY = window.frame.maxY + Metric.tooltipGap
            tooltip.showAbove(folder: session.label, branch: session.branch,
                              centerX: centerX, bottomY: bottomY)
        } else {
            tooltip.hide()
        }
    }

    // MARK: - Подгонка размера окна

    /// Детерминированный размер ряда светофоров (без масштаба) — из констант Metric.
    /// Должен точно совпадать с интринсик-размером SwiftUI, иначе окно режет контент.
    private func baseRowSize() -> CGSize {
        let sessions = store.sessions
        guard !sessions.isEmpty else { return .zero }
        let gaps = Metric.rowGap * CGFloat(sessions.count - 1)

        // «?» сверху (гориз./треуг.) добавляет высоту ряда; справа (верт.) — ширину.
        // Подписи: снизу (гориз./треуг.) добавляют высоту; слева (верт.) — ширину.
        let anyQuestion = sessions.contains(where: { $0.awaitingQuestion })
        let labelExtent = ui.showLabels ? Metric.labelThickness + Metric.labelGap : 0

        switch ui.shape {
        case .horizontal:
            // Лампы в ряд: ширина светофора = blockHeight, высота = blockWidth.
            let width = Metric.blockHeight * CGFloat(sessions.count) + gaps + 2 * Metric.rowPad
            var lightHeight = Metric.blockWidth + labelExtent
            if anyQuestion { lightHeight += Metric.questionGap + Metric.blockWidth }
            return CGSize(width: width, height: lightHeight + 2 * Metric.rowPad)

        case .triangular:
            // Квадрат triSide; круглая «?» сверху по центру, подпись снизу.
            let width = Metric.triSide * CGFloat(sessions.count) + gaps + 2 * Metric.rowPad
            var lightHeight = Metric.triSide + labelExtent
            if anyQuestion { lightHeight += Metric.questionGap + Metric.blockWidth }
            return CGSize(width: width, height: lightHeight + 2 * Metric.rowPad)

        case .vertical:
            // «?» справа и подпись слева увеличивают ширину — по каждой сессии.
            var width: CGFloat = 0
            for session in sessions {
                width += Metric.blockWidth + labelExtent
                if session.awaitingQuestion { width += Metric.questionGap + Metric.blockWidth }
            }
            width += gaps + 2 * Metric.rowPad
            return CGSize(width: width, height: Metric.blockHeight + 2 * Metric.rowPad)
        }
    }

    private func scheduleResize() {
        guard let window else { return }
        // Нет сессий — прячем окно (приложение продолжает жить и слушать порт).
        if store.sessions.isEmpty {
            tooltip?.hide()
            if window.isVisible { window.orderOut(nil) }
            return
        }
        if !window.isVisible { window.orderFrontRegardless() }
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
