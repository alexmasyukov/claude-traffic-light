import SwiftUI
import Combine

/// Состояние агента в одной сессии Claude Code.
enum AgentStatus: String {
    case idle      // 🟢 зелёный — агент закончил, ждёт пользователя
    case thinking  // 🟡 жёлтый — думает / готовится / генерирует ответ
    case working   // 🔴 красный — выполняет инструмент

    var color: Color {
        switch self {
        case .idle:     return Color(red: 0.20, green: 0.80, blue: 0.35)
        case .thinking: return Color(red: 0.98, green: 0.78, blue: 0.10)
        case .working:  return Color(red: 0.95, green: 0.25, blue: 0.22)
        }
    }
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
            let branch = SessionState.gitBranch(cwd)
            Task { @MainActor in self.branch = branch }
        }
    }

    private static func gitBranch(_ cwd: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", cwd, "rev-parse", "--abbrev-ref", "HEAD"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let name = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (name?.isEmpty == false) ? name : nil
        } catch { return nil }
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
        case .stop:
            status = .idle
            awaitingQuestion = false
        case .sessionStart:
            status = .idle
            awaitingQuestion = false
        case .sessionEnd:
            status = .idle
            awaitingQuestion = false
        }
    }
}

/// Хранилище всех активных сессий. Для MVP показываем последнюю активную.
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [SessionState] = []
    @Published var activeID: String?

    private var index: [String: SessionState] = [:]

    var active: SessionState? {
        guard let id = activeID else { return sessions.last }
        return index[id] ?? sessions.last
    }

    func handle(sessionID: String, event: HookEvent, cwd: String?) {
        let session: SessionState
        if let existing = index[sessionID] {
            session = existing
        } else {
            let label = cwd.map { ($0 as NSString).lastPathComponent } ?? "session"
            session = SessionState(id: sessionID, label: label)
            index[sessionID] = session
            sessions.append(session)
        }
        if let cwd {
            if session.label == "session" {
                session.label = (cwd as NSString).lastPathComponent
            }
            if session.cwd != cwd { session.cwd = cwd }
            session.refreshBranch()
        }

        if event == .sessionEnd {
            index[sessionID] = nil
            sessions.removeAll { $0.id == sessionID }
            if activeID == sessionID { activeID = sessions.last?.id }
            return
        }

        session.apply(event)
        activeID = sessionID   // последняя активность = активный светофор
    }
}
