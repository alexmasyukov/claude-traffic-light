import SwiftUI

/// Один вертикальный светофор: лампы + доп-секция «вопрос» справа.
/// onHover пробрасывается наружу для показа всплывающей подсказки.
struct TrafficLightView: View {
    @ObservedObject var session: SessionState
    var shape: LightShape = .vertical
    var onHover: (Bool) -> Void = { _ in }

    @State private var hovered = false

    var body: some View {
        content
            .animation(Anim.status, value: session.status)
            .animation(Anim.question, value: session.awaitingQuestion)
            .animation(Anim.hover, value: hovered)
            .onHover { inside in
                hovered = inside
                onHover(inside)
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
    }

    /// Раскладка одного светофора. Доп-секция «?»: сверху слева в горизонтальном
    /// виде, справа — в вертикальном и треугольном.
    @ViewBuilder private var content: some View {
        if shape == .horizontal {
            VStack(alignment: .leading, spacing: 0) {
                if session.awaitingQuestion {
                    questionBlock.transition(.opacity)
                    Spacer().frame(height: Metric.questionGap)
                }
                lampBlock
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                lampBlock
                if session.awaitingQuestion {
                    Spacer().frame(width: Metric.questionGap)
                    questionBlock.transition(.opacity)
                }
            }
        }
    }

    // MARK: - Светофор

    @ViewBuilder private var lampSequence: some View {
        lamp(.working)
        lamp(.thinking)
        lamp(.idle)
    }

    /// Лампы в корпусе — раскладка зависит от формы.
    private var lampBlock: some View {
        Group {
            switch shape {
            case .vertical:
                VStack(spacing: Metric.lampSpacing) { lampSequence }
            case .horizontal:
                HStack(spacing: Metric.lampSpacing) { lampSequence }
            case .triangular:
                // 🟡 сверху по центру, 🟢 слева, 🔴 справа.
                VStack(spacing: Metric.lampSpacing) {
                    lamp(.thinking)
                    HStack(spacing: Metric.lampSpacing) {
                        lamp(.idle)
                        lamp(.working)
                    }
                }
            }
        }
        .padding(Metric.blockPadding)
        .background(corpus)
        .overlay(border)
    }

    private func lamp(_ which: AgentStatus) -> some View {
        let on = session.status == which
        let color = Palette.lamp(for: which)
        return Circle()
            .fill(color)
            .frame(width: Metric.lamp, height: Metric.lamp)
            .opacity(on ? 1 : Metric.lampInactiveOpacity)
            .overlay(Circle().stroke(Color.white.opacity(on ? Metric.lampActiveStroke : 0), lineWidth: 0.8))
            // Спиннер «идёт процесс» — только на активной лампе, кроме idle (готово)
            // и кроме ожидания ответа на вопрос (лампа горит ровно, процесс не идёт).
            .overlay {
                if on && which != .idle && !session.awaitingQuestion {
                    Spinner(color: Palette.spinner(for: which))
                        .frame(width: Metric.lamp * Metric.spinnerFactor,
                               height: Metric.lamp * Metric.spinnerFactor)
                }
            }
            .shadow(color: on ? color.opacity(0.9) : .clear, radius: on ? Metric.lampGlow : 0)
    }

    // MARK: - Доп-секция «вопрос»

    /// Горящая синяя заливка на всю область блока с отступом от края, «?» по центру.
    private var questionBlock: some View {
        Image(systemName: "questionmark")
            .font(.system(size: Metric.lamp * Metric.questionMarkFactor, weight: .heavy))
            .foregroundColor(.white)
            .rotationEffect(shape == .horizontal ? .degrees(-90) : .zero)   // «?» повёрнут под горизонтальный вид
            .frame(width: Metric.lamp, height: Metric.lamp)
            .padding(Metric.blockPadding)
            .background(
                RoundedRectangle(cornerRadius: Metric.corner - Metric.questionInset, style: .continuous)
                    .fill(Palette.question)
                    .shadow(color: Palette.question, radius: Metric.questionGlow)      // горит, как лампа
                    .shadow(color: Palette.question.opacity(0.7), radius: Metric.questionGlowSoft)
                    .padding(Metric.questionInset)
            )
            .background(corpus)
            .overlay(border)
    }

    // MARK: - Общие элементы корпуса

    private var corpus: some View {
        RoundedRectangle(cornerRadius: Metric.corner, style: .continuous)
            .fill(hovered ? Palette.corpusHover : Palette.corpus)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: Metric.corner, style: .continuous)
            .stroke(Palette.border, lineWidth: 1)
    }
}

/// Крутящаяся дуга — индикатор «идёт процесс» по центру активной лампы.
struct Spinner: View {
    var color: Color = .white
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0, to: Metric.spinnerTrim)
            .stroke(color.opacity(Metric.spinnerOpacity),
                    style: StrokeStyle(lineWidth: Metric.spinnerLineWidth, lineCap: .round))
            .rotationEffect(.degrees(spin ? 360 : 0))
            .onAppear {
                withAnimation(Anim.spin) { spin = true }
            }
    }
}

/// Корневой вид окна — горизонтальный ряд светофоров по всем активным сессиям.
/// Размер интринсик (scaleEffect не меняет layout) — окно подгоняется на стороне
/// AppKit по детерминированному размеру × scale (см. AppController).
struct RootView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var ui: UIState
    var onHover: (Bool, SessionState?) -> Void = { _, _ in }
    var onScaleChanged: () -> Void = {}

    var body: some View {
        // Нет сессий — ряд пустой (окно прячет AppController), само приложение живёт.
        HStack(alignment: ui.shape == .horizontal ? .bottom : .top, spacing: Metric.rowGap) {
            ForEach(store.sessions) { session in
                TrafficLightView(session: session, shape: ui.shape) { inside in
                    onHover(inside, session)
                }
            }
        }
        .padding(Metric.rowPad)
        .fixedSize()
        .scaleEffect(ui.scale, anchor: .topLeading)
        // Прижимаем контент к верхнему-левому углу окна: иначе SwiftUI центрирует
        // немасштабированный бокс и scaleEffect выкидывает его за правый-нижний край.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(Anim.scale, value: ui.scale)
        .animation(Anim.scale, value: ui.shape)
        .animation(Anim.sessions, value: store.sessions.count)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            ui.cycleScale()
            onScaleChanged()
        }
    }
}
