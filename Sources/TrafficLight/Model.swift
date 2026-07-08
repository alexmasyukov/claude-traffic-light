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
    case stopAsk          = "StopAsk"   // синтетический: Stop, но ход завершён текстовым вопросом
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
            // Инструмент отработал — любой связанный с ним вопрос/разрешение снят
            // (иначе «?» от AskUserQuestion зависает, пока агент формирует ответ).
            status = .thinking
            awaitingQuestion = false
        case .notification:
            // Notification прилетает двух видов: запрос разрешения (агент активен —
            // нужен ответ, «?») и простой ввода ≥60с (idle_prompt — агент уже закончил,
            // вопроса нет). Различаем по активности (локале-независимо) и НИКОГДА не гасим
            // уже висящий вопрос: реальный запрос возможен только пока агент работает,
            // в простое (status == .idle) idle-пинг игнорируем — иначе «?» ложно повиснет.
            if status != .idle { awaitingQuestion = true }
        case .stopAsk:
            // Агент закончил ход, но задал вопрос — красный + «?» (ждём ответа).
            status = .working
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
/// Форма/раскладка ламп в одном светофоре.
enum LightShape: String, CaseIterable {
    case vertical      // лампы столбиком, «?» справа
    case horizontal    // лампы в ряд, «?» сверху слева
    case triangular    // 🟡 сверху по центру, 🟢 слева, 🔴 справа; «?» справа
}

@MainActor
final class UIState: ObservableObject {
    @Published var scale: Double
    /// Форма светофоров, циклится по меню «Сменить вид». Персист.
    @Published var shape: LightShape
    /// Показывать ли подписи папок (меню «Показать/Скрыть названия»). Персист.
    @Published var showLabels: Bool

    init() {
        let saved = UserDefaults.standard.double(forKey: Config.Key.uiScale)
        scale = (saved >= Config.scaleMin && saved <= Config.scaleMax) ? saved : Config.scaleMin
        let savedShape = UserDefaults.standard.string(forKey: Config.Key.shape)
        shape = savedShape.flatMap(LightShape.init(rawValue:)) ?? .vertical
        showLabels = UserDefaults.standard.bool(forKey: Config.Key.showLabels)
    }

    func cycleScale() {
        scale = scale >= Config.scaleMax - 0.01 ? Config.scaleMin : scale + Config.scaleStep
        UserDefaults.standard.set(scale, forKey: Config.Key.uiScale)
    }

    /// Следующая форма по кругу: вертикальный → горизонтальный → треугольный → …
    func cycleShape() {
        let all = LightShape.allCases
        let next = all.firstIndex(of: shape).map { all[($0 + 1) % all.count] } ?? .vertical
        shape = next
        UserDefaults.standard.set(shape.rawValue, forKey: Config.Key.shape)
    }

    func toggleLabels() {
        showLabels.toggle()
        UserDefaults.standard.set(showLabels, forKey: Config.Key.showLabels)
    }
}
