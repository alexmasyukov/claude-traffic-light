import SwiftUI
import AppKit

let kPort: UInt16 = 47615

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    let store = SessionStore()
    var window: NSWindow!
    var server: TrafficServer?

    private let originKey = "windowOrigin"   // ключ UserDefaults для позиции

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Плавающее безрамочное окно поверх всех приложений и на всех Spaces.
        let content = NSHostingView(rootView: RootView(store: store))
        content.frame = NSRect(x: 0, y: 0, width: 92, height: 78)

        let window = NSWindow(
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
            window.setFrameOrigin(NSPoint(x: vf.maxX - 80, y: vf.maxY - 128))
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
