import SwiftUI

/// Геометрия ряда светофоров (в 2 раза меньше исходной задумки).
enum Metric {
    static let lamp: CGFloat = 13
    static let lampSpacing: CGFloat = 4
    static let blockPadding: CGFloat = 5
    static let corner: CGFloat = 7

    static let rowGap: CGFloat = 12          // отступ между светофорами
    static let rowPad: CGFloat = 8           // поля ряда под свечение
    static let questionGap: CGFloat = 4      // отступ доп-секции от светофора
    static let questionInset: CGFloat = 2    // отступ синей заливки от края корпуса

    static let spinnerFactor: CGFloat = 0.62 // диаметр спиннера от диаметра лампы
    static let spinnerTrim: CGFloat = 0.28
    static let spinnerLineWidth: CGFloat = 2
    static let questionMarkFactor: CGFloat = 0.72

    static let lampGlow: CGFloat = 5
    static let questionGlow: CGFloat = 6
    static let questionGlowSoft: CGFloat = 3

    static let lampInactiveOpacity: Double = 0.16
    static let lampActiveStroke: Double = 0.35
    static let spinnerOpacity: Double = 0.92

    // Подпись папки под/сбоку светофора (режим «Показать названия»).
    static let labelFont: CGFloat = 7.5      // кегль подписи
    static let labelThickness: CGFloat = 10  // толщина строки (высота под/ширина сбоку)
    static let labelGap: CGFloat = 2         // отступ подписи от светофора

    /// Высота блока светофора.
    static var blockHeight: CGFloat { 3 * lamp + 2 * lampSpacing + 2 * blockPadding }

    /// Ширина одного блока (светофор или доп-секция).
    static var blockWidth: CGFloat { lamp + 2 * blockPadding }

    /// Сторона квадратного блока в треугольной раскладке (2 лампы × 2 лампы).
    static var triSide: CGFloat { 2 * lamp + lampSpacing + 2 * blockPadding }

    // Треугольная раскладка — равносторонний треугольник центров ламп: все три
    // расстояния между центрами равны (lamp + lampSpacing), поэтому вертикальный
    // зазор VStack меньше горизонтального (высота равностороннего = сторона·√3/2).
    static var triLampSpacingV: CGFloat { (CGFloat(3).squareRoot() / 2) * (lamp + lampSpacing) - lamp }
    /// Высота контента (без паддинга) в треугольной раскладке.
    static var triContentHeight: CGFloat { 2 * lamp + triLampSpacingV }
    /// Вертикальный отступ, центрирующий контент в квадрате triSide.
    static var triPadV: CGFloat { (triSide - triContentHeight) / 2 }
}

/// Цвета приложения.
enum Palette {
    static let lampIdle     = Color(red: 0.20, green: 0.80, blue: 0.35)  // 🟢
    static let lampThinking = Color(red: 0.98, green: 0.78, blue: 0.10)  // 🟡
    static let lampWorking  = Color(red: 0.95, green: 0.25, blue: 0.22)  // 🔴

    static let corpus      = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let corpusHover = Color(red: 0.17, green: 0.17, blue: 0.19)   // ярче при наведении
    static let border      = Color.white.opacity(0.12)

    static let question       = Color(red: 0.30, green: 0.55, blue: 0.98)
    /// Спиннер на жёлтой лампе: жёлтый лампы × 0.5 (белый на жёлтом теряется).
    static let spinnerOnYellow = Color(red: 0.49, green: 0.39, blue: 0.05)

    static let tooltipBackground = Color.black.opacity(0.88)
    static let tooltipBorder     = Color.white.opacity(0.14)

    static let label = Color.white.opacity(0.72)   // подпись папки

    static func lamp(for status: AgentStatus) -> Color {
        switch status {
        case .idle:     return lampIdle
        case .thinking: return lampThinking
        case .working:  return lampWorking
        }
    }

    static func spinner(for status: AgentStatus) -> Color {
        status == .thinking ? spinnerOnYellow : .white
    }
}

/// Длительности и кривые анимаций.
enum Anim {
    static let status   = Animation.easeOut(duration: 0.12)
    static let question = Animation.easeOut(duration: 0.12)
    static let hover    = Animation.easeOut(duration: 0.15)
    static let scale    = Animation.easeOut(duration: 0.22)
    static let sessions = Animation.easeOut(duration: 0.16)
    static let spin     = Animation.linear(duration: 0.8).repeatForever(autoreverses: false)
    /// Длительность анимации кадра окна — совпадает со scale, чтобы окно не резало контент.
    static let windowDuration: Double = 0.22
}

/// Прочие константы приложения.
enum Config {
    static let port: UInt16 = 47615
    static let scaleMin: Double = 1.0
    static let scaleMax: Double = 1.5
    static let scaleStep: Double = 0.1

    enum Key {
        static let windowOrigin = "windowOrigin"
        static let uiScale = "uiScale"
        static let shape = "lightShape"
        static let showLabels = "showLabels"
    }
}
