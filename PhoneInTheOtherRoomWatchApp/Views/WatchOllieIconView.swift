import SwiftUI

struct WatchOllieIconView: View {
    var mood: OllieMood

    var body: some View {
        ZStack {
            Image("OllieMascot")
                .resizable()
                .interpolation(.none)
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.black.opacity(0.75), lineWidth: 2))
                .saturation(mood == .sad ? 0.45 : 0.9)
            if mood == .alert {
                Text("!")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .offset(x: 28, y: -25)
            }
        }
        .frame(width: 72, height: 72)
    }
}
