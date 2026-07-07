import SwiftUI

/// Геометрия (в 2 раза меньше исходной).
enum Metric {
    static let lamp: CGFloat = 13
    static let lampSpacing: CGFloat = 4
    static let blockPadding: CGFloat = 5
    static let corner: CGFloat = 7

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

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            lampColumn
            if session.awaitingQuestion {
                Spacer().frame(width: 4)            // ровно 4px справа от светофора
                questionBlock
                    .transition(.opacity)
            }
        }
        .padding(5)
        .scaleEffect(hovered ? 1.2 : 1.0)          // «навели точно на меня»
        .animation(.easeOut(duration: 0.12), value: session.status)
        .animation(.easeOut(duration: 0.12), value: session.awaitingQuestion)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: hovered)
        .onHover { inside in
            hovered = inside
            onHover(inside)
        }
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
                    Spinner().frame(width: Metric.lamp * 0.62, height: Metric.lamp * 0.62)
                }
            }
            .shadow(color: on ? which.color.opacity(0.9) : .clear, radius: on ? 5 : 0)
    }

    /// Доп-секция «вопрос» — блок как у светофора с горящим кружком «?».
    private var questionBlock: some View {
        let blue = Color(red: 0.30, green: 0.55, blue: 0.98)
        return ZStack {
            Circle()
                .fill(blue)
                .frame(width: Metric.lamp, height: Metric.lamp)
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.8))
                .shadow(color: blue, radius: 6)          // горит, как лампа светофора
                .shadow(color: blue.opacity(0.7), radius: 3)
            Image(systemName: "questionmark")
                .font(.system(size: Metric.lamp * 0.66, weight: .heavy))
                .foregroundColor(.white)
        }
        .padding(Metric.blockPadding)
        .background(blockBackground)
        .overlay(blockBorder)
    }

    private var blockBackground: some View {
        RoundedRectangle(cornerRadius: Metric.corner, style: .continuous)
            .fill(Color.black.opacity(0.82))
    }

    private var blockBorder: some View {
        RoundedRectangle(cornerRadius: Metric.corner, style: .continuous)
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
    }
}

/// Крутящаяся дуга — индикатор «идёт процесс» по центру активной лампы.
struct Spinner: View {
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.28)
            .stroke(
                Color.white.opacity(0.92),
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
        Group {
            if let session = store.active {
                TrafficLightView(session: session, onHover: onHover)
            } else {
                TrafficLightView(session: SessionState(id: "—", label: "idle"), onHover: onHover)
            }
        }
    }
}
