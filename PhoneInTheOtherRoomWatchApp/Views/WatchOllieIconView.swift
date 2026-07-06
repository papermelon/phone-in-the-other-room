import SwiftUI

struct WatchOllieIconView: View {
    var mood: OllieMood

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundColor)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.22), lineWidth: 1))
            Circle()
                .fill(.white)
                .frame(width: 46, height: 42)
                .offset(y: 4)
            Circle()
                .fill(.black.opacity(0.78))
                .frame(width: 22, height: 24)
                .offset(x: -13, y: -1)
            ear
                .offset(x: -23, y: -19)
            ear
                .scaleEffect(x: -1, y: 1)
                .offset(x: 23, y: -19)
            Circle()
                .fill(.black)
                .frame(width: 4, height: 4)
                .offset(x: -7, y: 1)
            Circle()
                .fill(.black)
                .frame(width: 4, height: 4)
                .offset(x: 9, y: 1)
            Capsule()
                .fill(.black)
                .frame(width: 10, height: 6)
                .offset(y: 10)
            mouth
            if mood == .alert {
                Text("!")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .offset(x: 28, y: -25)
            }
        }
        .frame(width: 72, height: 72)
    }

    private var backgroundColor: Color {
        switch mood {
        case .sad: return Color(red: 0.18, green: 0.25, blue: 0.34)
        case .alert: return Color(red: 0.42, green: 0.28, blue: 0.10)
        case .proud, .happy: return Color(red: 0.15, green: 0.38, blue: 0.22)
        default: return Color(red: 0.11, green: 0.18, blue: 0.12)
        }
    }

    private var ear: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(.black.opacity(0.86))
            .frame(width: 16, height: 28)
            .rotationEffect(.degrees(-28))
    }

    private var mouth: some View {
        Group {
            if mood == .sad {
                Capsule()
                    .stroke(.black, lineWidth: 2)
                    .frame(width: 12, height: 7)
                    .rotationEffect(.degrees(180))
                    .offset(y: 18)
            } else {
                Capsule()
                    .fill(Color(red: 0.84, green: 0.22, blue: 0.20))
                    .frame(width: 10, height: 6)
                    .offset(y: 18)
            }
        }
    }
}
