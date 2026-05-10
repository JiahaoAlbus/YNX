import SwiftUI

struct RootView: View {
    @EnvironmentObject private var viewModel: YNXNetworkViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: YNXTab = .home
    @State private var selectedActionMode: ChainActionMode = .transfer
    @State private var showLaunch = true
    @Namespace private var tabNamespace

    var body: some View {
        ZStack {
            PhoneBackground()

            currentScreen
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))

            if showLaunch {
                LaunchCover()
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
                    .zIndex(5)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(.clear)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task {
            await viewModel.refresh()
            guard !reduceMotion else {
                showLaunch = false
                return
            }
            try? await Task.sleep(nanoseconds: 950_000_000)
            withAnimation(.easeInOut(duration: 0.42)) {
                showLaunch = false
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.refresh() }
            }
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch selectedTab {
        case .home:
            DashboardView(selectedTab: $selectedTab, selectedActionMode: $selectedActionMode)
        case .wallet:
            WalletView()
        case .actions:
            ChainActionsView(selectedMode: $selectedActionMode)
        case .browser:
            YNXBrowserView()
        case .monitor:
            NetworkView()
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 4) {
            ForEach(YNXTab.allCases) { tab in
                Button {
                    withAnimation(YNXTheme.standard) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(YNXTheme.klein)
                                    .frame(width: 48, height: 32)
                                    .matchedGeometryEffect(id: "tab-pill", in: tabNamespace)
                            }
                            Image(systemName: tab.symbol)
                            .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(selectedTab == tab ? .white : YNXTheme.muted)
                        }
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(selectedTab == tab ? YNXTheme.klein : YNXTheme.muted)
                    }
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.72), lineWidth: 1))
        .shadow(color: YNXTheme.klein.opacity(0.16), radius: 24, x: 0, y: 12)
    }
}

struct LaunchCover: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mark = false
    @State private var glow = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Circle()
                .fill(YNXTheme.klein.opacity(0.12))
                .frame(width: 230, height: 230)
                .blur(radius: 34)
                .scaleEffect(glow ? 1.12 : 0.9)

            VStack(spacing: 18) {
                YNXLogoMark(size: 132)
                    .scaleEffect(mark ? 1 : 0.88)
                    .opacity(mark ? 1 : 0)
                Text("PUBLIC TESTNET")
                    .font(.caption.monospaced().weight(.bold))
                    .tracking(2.2)
                    .foregroundStyle(YNXTheme.klein)
                    .opacity(mark ? 1 : 0)
            }
        }
        .onAppear {
            guard !reduceMotion else {
                mark = true
                glow = true
                return
            }
            withAnimation(YNXTheme.slow) {
                mark = true
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}
