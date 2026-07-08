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
        .background(corpusFill)
        .overlay(corpusBorder)
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

    /// Заливка корпуса светофора: прямоугольник (верт./гориз.) или треугольник
    /// с закруглениями вокруг ламп (triangular).
    @ViewBuilder private var corpusFill: some View {
        if shape == .triangular {
            triangleShape.fill(hovered ? Palette.corpusHover : Palette.corpus)
        } else {
            corpus
        }
    }

    @ViewBuilder private var corpusBorder: some View {
        if shape == .triangular {
            triangleShape.stroke(Palette.border, lineWidth: 1)
        } else {
            border
        }
    }

    /// Треугольник (вершиной вверх), «раздутый» вокруг центров трёх ламп на
    /// (радиус лампы + отступ) — даёт скруглённые углы точно по лампам.
    private var triangleShape: RoundedInflatedTriangle {
        RoundedInflatedTriangle(radius: Metric.lamp / 2 + Metric.blockPadding)
    }

    // Прямоугольный корпус (верт./гориз.) и доп-секция «?».
    private var corpus: some View {
        RoundedRectangle(cornerRadius: Metric.corner, style: .continuous)
            .fill(hovered ? Palette.corpusHover : Palette.corpus)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: Metric.corner, style: .continuous)
            .stroke(Palette.border, lineWidth: 1)
    }
}

/// Треугольник вершиной вверх, «раздутый» на `radius` вокруг центров трёх ламп
/// (🟡 сверху по центру, 🟢 снизу слева, 🔴 снизу справа) — сумма Минковского
/// с диском: каждый угол — дуга радиуса `radius`, между углами прямые рёбра.
struct RoundedInflatedTriangle: Shape {
    var radius: CGFloat

    /// Центры ламп в системе координат корпуса (после padding).
    private func vertices(in rect: CGRect) -> [CGPoint] {
        let inset = Metric.blockPadding + Metric.lamp / 2
        return [
            CGPoint(x: rect.midX,          y: rect.minY + inset),   // 🟡 вершина
            CGPoint(x: rect.minX + inset,  y: rect.maxY - inset),   // 🟢 левый низ
            CGPoint(x: rect.maxX - inset,  y: rect.maxY - inset),   // 🔴 правый низ
        ]
    }

    func path(in rect: CGRect) -> Path {
        let pts = vertices(in: rect)
        let n = pts.count
        let centroid = CGPoint(x: pts.reduce(0) { $0 + $1.x } / CGFloat(n),
                               y: pts.reduce(0) { $0 + $1.y } / CGFloat(n))

        // Внешняя нормаль ребра a→b (наружу от центроида), единичная.
        func outwardNormal(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max((dx * dx + dy * dy).squareRoot(), 0.0001)
            var nx = -dy / len, ny = dx / len
            let mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2
            if nx * (mx - centroid.x) + ny * (my - centroid.y) < 0 { nx = -nx; ny = -ny }
            return CGPoint(x: nx, y: ny)
        }

        var path = Path()
        var started = false
        for i in 0..<n {
            let prev = pts[(i - 1 + n) % n]
            let curr = pts[i]
            let next = pts[(i + 1) % n]
            let nIn = outwardNormal(prev, curr)
            let nOut = outwardNormal(curr, next)
            let aIn = atan2(nIn.y, nIn.x)
            let aOut = atan2(nOut.y, nOut.x)
            // Кратчайший поворот от aIn к aOut — трасса внешнего угла.
            var delta = aOut - aIn
            let twoPi = CGFloat.pi * 2
            while delta <= -CGFloat.pi { delta += twoPi }
            while delta > CGFloat.pi { delta -= twoPi }
            // Дугу вокруг вершины сэмплируем отрезками (без неоднозначности clockwise).
            let steps = max(2, Int(abs(delta) / (CGFloat.pi / 18)))
            for s in 0...steps {
                let a = aIn + delta * CGFloat(s) / CGFloat(steps)
                let pt = CGPoint(x: curr.x + radius * cos(a), y: curr.y + radius * sin(a))
                if started { path.addLine(to: pt) } else { path.move(to: pt); started = true }
            }
        }
        path.closeSubpath()
        return path
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
