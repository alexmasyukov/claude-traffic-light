import SwiftUI

/// Геометрия (в 2 раза меньше исходной).
enum Metric {
    static let lamp: CGFloat = 13
    static let lampSpacing: CGFloat = 4
    static let blockPadding: CGFloat = 5
    static let corner: CGFloat = 7
    static let labelWidth: CGFloat = 13

    /// Высота блока светофора — по ней тянем вертикальную подпись.
    static var blockHeight: CGFloat {
        3 * lamp + 2 * lampSpacing + 2 * blockPadding
    }
}

/// Один вертикальный светофор: подпись слева (вертикально) + лампы, секция «вопрос» снизу.
struct TrafficLightView: View {
    @ObservedObject var session: SessionState

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            verticalLabel
            Spacer().frame(width: 3)
            lampColumn
            if session.awaitingQuestion {
                Spacer().frame(width: 4)            // ровно 4px справа от светофора
                questionBlock
                    .transition(.opacity)
            }
        }
        .padding(5)
        .animation(.easeOut(duration: 0.12), value: session.status)
        .animation(.easeOut(duration: 0.12), value: session.awaitingQuestion)
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
            Text("?")
                .font(.system(size: Metric.lamp * 0.72, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(Metric.blockPadding)
        .background(
            RoundedRectangle(cornerRadius: Metric.corner, style: .continuous)
                .fill(Color.black.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metric.corner, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var verticalLabel: some View {
        Text(session.label)
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.65))
            .lineLimit(1)
            .truncationMode(.tail)
            .fixedSize()
            .frame(width: Metric.blockHeight)          // «длина» строки = высота светофора
            .rotationEffect(.degrees(-90))
            .frame(width: Metric.labelWidth, height: Metric.blockHeight)
    }

    private var lampColumn: some View {
        VStack(spacing: Metric.lampSpacing) {
            lamp(.working)
            lamp(.thinking)
            lamp(.idle)
        }
        .padding(Metric.blockPadding)
        .background(
            RoundedRectangle(cornerRadius: Metric.corner, style: .continuous)
                .fill(Color.black.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metric.corner, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func lamp(_ which: AgentStatus) -> some View {
        let on = session.status == which
        return Circle()
            .fill(which.color)
            .frame(width: Metric.lamp, height: Metric.lamp)
            .opacity(on ? 1 : 0.16)
            .overlay(Circle().stroke(Color.white.opacity(on ? 0.35 : 0), lineWidth: 0.8))
            .shadow(color: on ? which.color.opacity(0.9) : .clear, radius: on ? 5 : 0)
    }
}

/// Корневой вид окна — для MVP показываем активную сессию.
struct RootView: View {
    @ObservedObject var store: SessionStore

    var body: some View {
        Group {
            if let session = store.active {
                TrafficLightView(session: session)
            } else {
                TrafficLightView(session: SessionState(id: "—", label: "idle"))
            }
        }
    }
}
