import SwiftUI

/// Геометрия (в 2 раза меньше исходной).
enum Metric {
    static let lamp: CGFloat = 13
    static let lampSpacing: CGFloat = 4
    static let blockPadding: CGFloat = 5
    static let corner: CGFloat = 7

    /// Размер холста-окна: с запасом полей под hover-увеличение и свечение.
    static let canvas: CGFloat = 140

    /// Высота блока светофора.
    static var blockHeight: CGFloat {
        3 * lamp + 2 * lampSpacing + 2 * blockPadding
    }
}

/// Один вертикальный светофор: лампы + доп-секция «вопрос» справа.
/// onHover пробрасывается наружу для показа всплывающей подсказки.
struct TrafficLightView: View {
    @ObservedObject var session: SessionState
    var onHover: (Bool) -> Void = { _ in }

    @State private var hovered = false
    // Пользовательский масштаб: двойной клик +10% до +50%, затем сброс. Хранится в UserDefaults.
    @AppStorage("uiScale") private var uiScale: Double = 1.0

    var body: some View {
        HStack(alignment: .top, spacing: 0) {          // «?» на уровне верхней (красной) лампы
            lampColumn
            if session.awaitingQuestion {
                Spacer().frame(width: 4)            // ровно 4px справа от светофора
                questionBlock
                    .transition(.opacity)
            }
        }
        .padding(5)
        .scaleEffect(uiScale)
        .animation(.easeOut(duration: 0.12), value: session.status)
        .animation(.easeOut(duration: 0.12), value: session.awaitingQuestion)
        .animation(.easeOut(duration: 0.15), value: hovered)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: uiScale)
        .onHover { inside in
            hovered = inside
            onHover(inside)
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onTapGesture(count: 2) {
            // 1.0 → 1.1 → … → 1.5 → 1.0
            uiScale = uiScale >= 1.49 ? 1.0 : (uiScale + 0.1)
        }
    }

    /// Корпус: ярче при наведении.
    private var corpusColor: Color {
        hovered ? Color(red: 0.17, green: 0.17, blue: 0.19)
                : Color(red: 0.07, green: 0.07, blue: 0.08)
    }

    private var lampColumn: some View {
        VStack(spacing: Metric.lampSpacing) {
            lamp(.working)
            lamp(.thinking)
            lamp(.idle)
        }
        .padding(Metric.blockPadding)
        .background(blockBackground)
        .overlay(blockBorder)
    }

    private func lamp(_ which: AgentStatus) -> some View {
        let on = session.status == which
        return Circle()
            .fill(which.color)
            .frame(width: Metric.lamp, height: Metric.lamp)
            .opacity(on ? 1 : 0.16)
            .overlay(Circle().stroke(Color.white.opacity(on ? 0.35 : 0), lineWidth: 0.8))
            // Спиннер «идёт процесс» — только на активной лампе, кроме idle (готово).
            .overlay {
                if on && which != .idle {
                    Spinner(color: spinnerColor(for: which))
                        .frame(width: Metric.lamp * 0.62, height: Metric.lamp * 0.62)
                }
            }
            .shadow(color: on ? which.color.opacity(0.9) : .clear, radius: on ? 5 : 0)
    }

    /// Доп-секция «вопрос»: горящая синяя заливка на всю область блока
    /// с отступом 2px от края, «?» по центру.
    private var questionBlock: some View {
        let blue = Color(red: 0.30, green: 0.55, blue: 0.98)
        return Image(systemName: "questionmark")
            .font(.system(size: Metric.lamp * 0.72, weight: .heavy))
            .foregroundColor(.white)
            .frame(width: Metric.lamp, height: Metric.lamp)
            .padding(Metric.blockPadding)
            .background(
                RoundedRectangle(cornerRadius: Metric.corner - 2, style: .continuous)
                    .fill(blue)
                    .shadow(color: blue, radius: 6)      // горит, как лампа
                    .shadow(color: blue.opacity(0.7), radius: 3)
                    .padding(2)                          // отступ 2px от края корпуса
            )
            .background(blockBackground)
            .overlay(blockBorder)
    }

    /// Цвет спиннера: жёлтый лампы, но заметно темнее (белый на жёлтом теряется), иначе белый.
    private func spinnerColor(for which: AgentStatus) -> Color {
        // Жёлтый лампы (0.98, 0.78, 0.10) × 0.5 → тёмный жёлтый.
        which == .thinking ? Color(red: 0.49, green: 0.39, blue: 0.05) : .white
    }

    private var blockBackground: some View {
        RoundedRectangle(cornerRadius: Metric.corner, style: .continuous)
            .fill(corpusColor)
    }

    private var blockBorder: some View {
        RoundedRectangle(cornerRadius: Metric.corner, style: .continuous)
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
    }
}

/// Крутящаяся дуга — индикатор «идёт процесс» по центру активной лампы.
struct Spinner: View {
    var color: Color = .white
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.28)
            .stroke(
                color.opacity(0.92),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .rotationEffect(.degrees(spin ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    spin = true
                }
            }
    }
}

/// Корневой вид окна — для MVP показываем активную сессию.
struct RootView: View {
    @ObservedObject var store: SessionStore
    var onHover: (Bool) -> Void = { _ in }

    var body: some View {
        // Фиксированный прозрачный холст: светофор строго по центру,
        // вокруг — поля, чтобы hover-увеличение и свечение не подрезались краями окна.
        ZStack {
            Color.clear
            if let session = store.active {
                TrafficLightView(session: session, onHover: onHover)
            } else {
                TrafficLightView(session: SessionState(id: "—", label: "idle"), onHover: onHover)
            }
        }
        .frame(width: Metric.canvas, height: Metric.canvas)
    }
}
