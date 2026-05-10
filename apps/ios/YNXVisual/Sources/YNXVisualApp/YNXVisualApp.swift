import SwiftUI

@main
struct YNXVisualApp: App {
    @StateObject private var viewModel = YNXNetworkViewModel()
    @StateObject private var walletStore = WalletStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
                .environmentObject(walletStore)
                #if os(macOS)
                .frame(width: 393, height: 852)
                #endif
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}
