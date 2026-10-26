import SwiftUI
import UserNotifications

@main
struct PixelPalsApp: App {
    @StateObject private var model = PetModel()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if model.profile == nil {
                    ProfileForm(title: "Adopt a pixel pal", buttonTitle: "Adopt", initial: nil) { model.save($0) }
                } else {
                    HomeView()
                }
            }
            .environmentObject(model)
            .environment(\.locale, .app)
            // Rebuild everything when the language changes so computed strings refresh too.
            .id(model.language)
            .preferredColorScheme(.dark)
        }
    }
}

extension View {
    func card() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }
}
