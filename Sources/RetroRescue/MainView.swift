import SwiftUI

struct MainView: View {
    @EnvironmentObject var state: VaultState

    var body: some View {
        Group {
            if state.isOpen {
                VaultBrowserView()
            } else {
                WelcomeView()
            }
        }
        .alert("Error", isPresented: .constant(state.error != nil)) {
            Button("OK") { state.error = nil }
        } message: {
            Text(state.error ?? "")
        }
    }
}
