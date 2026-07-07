import Foundation
import Combine

/// Состояние агента в одной сессии Claude Code.
enum AgentStatus: String {
    case idle      // 🟢 агент закончил, ждёт пользователя
    case thinking  // 🟡 думает / готовится / генерирует ответ
    case working   // 🔴 выполняет инструмент
}

/// Событие хука Claude Code.
enum HookEvent: String {
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse       = "PreToolUse"
    case postToolUse      = "PostToolUse"
    case notification     = "Notification"
    case stop             = "Stop"
    case sessionStart     = "SessionStart"
    case sessionEnd       = "SessionEnd"
}

/// Одна сессия — то, что рисуем как один светофор.
final class SessionState: ObservableObject, Identifiable {
    let id: String                 // session_id из хука
    @Published var status: AgentStatus = .idle
    @Published var awaitingQuestion = false
    @Published var label: String   // короткое имя (папка проекта)
    @Published var branch: String? // git-ветка в cwd
    var cwd: String?

    init(id: String, label: String) {
        self.id = id
        self.label = label
    }

    /// Асинхронно определяем git-ветку в cwd, не блокируя main.
    func refreshBranch() {
        guard let cwd else { return }
        DispatchQueue.global(qos: .utility).async {
            let branch = Git.branch(in: cwd)
            Task { @MainActor in self.branch = branch }
        }
    }

    /// Применить событие хука к состоянию.
    func apply(_ event: HookEvent) {
        switch event {
        case .userPromptSubmit:
            status = .thinking
            awaitingQuestion = false
        case .preToolUse:
            status = .working
            awaitingQuestion = false
        case .postToolUse:
            status = .thinking
        case .notification:
            awaitingQuestion = true
        case .stop, .sessionStart, .sessionEnd:
            status = .idle
            awaitingQuestion = false
        }
    }
}

/// Хранилище активных сессий — одна на каждый светофор в ряду.
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [SessionState] = []

    private var index: [String: SessionState] = [:]

    func handle(sessionID: String, event: HookEvent, cwd: String?) {
        if event == .sessionEnd {
            guard index.removeValue(forKey: sessionID) != nil else { return }
            sessions.removeAll { $0.id == sessionID }
            return
        }

        let session = index[sessionID] ?? register(sessionID, cwd: cwd)
        if let cwd {
            if session.label == "session" {
                session.label = (cwd as NSString).lastPathComponent
            }
            if session.cwd != cwd { session.cwd = cwd }
            session.refreshBranch()
        }
        session.apply(event)
    }

    private func register(_ sessionID: String, cwd: String?) -> SessionState {
        let label = cwd.map { ($0 as NSString).lastPathComponent } ?? "session"
        let session = SessionState(id: sessionID, label: label)
        index[sessionID] = session
        sessions.append(session)
        return session
    }
}

/// Общий масштаб ряда: двойной клик +10% до +50%, затем сброс. Персист в UserDefaults.
@MainActor
final class UIState: ObservableObject {
    @Published var scale: Double

    init() {
        let saved = UserDefaults.standard.double(forKey: Config.Key.uiScale)
        scale = (saved >= Config.scaleMin && saved <= Config.scaleMax) ? saved : Config.scaleMin
    }

    func cycleScale() {
        scale = scale >= Config.scaleMax - 0.01 ? Config.scaleMin : scale + Config.scaleStep
        UserDefaults.standard.set(scale, forKey: Config.Key.uiScale)
    }
}
