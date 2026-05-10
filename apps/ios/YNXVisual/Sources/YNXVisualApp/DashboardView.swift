import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: YNXNetworkViewModel
    @EnvironmentObject private var walletStore: WalletStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedTab: YNXTab
    @Binding var selectedActionMode: ChainActionMode
    @State private var heroLift = false

    var body: some View {
        PageContainer {
            ScreenHeader(
                eyebrow: "YNX Public Testnet",
                title: "Web4 Command Center",
                subtitle: "Wallet, policy, session, AI and chain operations in one native client."
            )
            .staggered(0)

            heroCard
                .staggered(1)

            serviceStrip
                .staggered(2)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(
                    title: "Network",
                    value: "\(viewModel.onlineCount)/\(viewModel.endpoints.count)",
                    footnote: "Reachable services",
                    symbol: "waveform.path.ecg",
                    accent: .green
                )
                .staggered(3)
                MetricTile(
                    title: "Validators",
                    value: "\(viewModel.bondedValidators)",
                    footnote: "Active bonded",
                    symbol: "shield.checkered",
                    accent: .indigo
                )
                .staggered(4)
                MetricTile(
                    title: "Chain",
                    value: YNX.chainID,
                    footnote: "Cosmos network id",
                    symbol: "network",
                    accent: YNXTheme.klein
                )
                .staggered(5)
                MetricTile(
                    title: "EVM",
                    value: YNX.evmChainID,
                    footnote: "Native compatibility",
                    symbol: "hexagon",
                    accent: .teal
                )
                .staggered(6)
            }

            GlassCard {
                SectionHeading(
                    title: "Primary flows",
                    subtitle: "Most-used user paths, optimized for one-tap entry."
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    DashboardActionTile(title: "Wallet", detail: "Create / import", symbol: "wallet.pass.fill", accent: YNXTheme.klein) {
                        select(.wallet)
                    }
                    DashboardActionTile(title: "Faucet", detail: "Get \(YNX.denom)", symbol: "drop.fill", accent: .cyan) {
                        select(.actions, mode: .faucet)
                    }
                    DashboardActionTile(title: "Transfer", detail: "Prepare + broadcast", symbol: "paperplane.fill", accent: .indigo) {
                        select(.actions, mode: .transfer)
                    }
                    DashboardActionTile(title: "Browser", detail: "dApp + explorer", symbol: "safari.fill", accent: .blue) {
                        select(.browser)
                    }
                }
                .padding(.top, 8)
            }
            .staggered(7)

            VStack(spacing: 10) {
                ActionCard(
                    title: "AI Agent Session",
                    detail: "Issue bounded policy + session token for machine actions.",
                    symbol: "key.radiowaves.forward",
                    accent: .green
                ) {
                    select(.actions, mode: .session)
                }
                ActionCard(
                    title: "Third-party API Test",
                    detail: "Authorize any endpoint under onchain policy limits.",
                    symbol: "bolt.shield",
                    accent: .teal
                ) {
                    select(.actions, mode: .thirdParty)
                }
                ActionCard(
                    title: "Cross-chain Bridge",
                    detail: "Universal bridge gateway entry for external assets.",
                    symbol: "link.badge.plus",
                    accent: YNXTheme.klein
                ) {
                    select(.actions, mode: .bridge)
                }
                ActionCard(
                    title: "Live Network Monitor",
                    detail: "Inspect RPC/REST/EVM/Faucet/Indexer health in real-time.",
                    symbol: "waveform.path.ecg.rectangle",
                    accent: .orange
                ) {
                    select(.monitor)
                }
            }
            .staggered(8)

            blockCard
                .staggered(9)
        }
    }

    private func select(_ tab: YNXTab, mode: ChainActionMode? = nil) {
        withAnimation(YNXTheme.standard) {
            if let mode {
                selectedActionMode = mode
            }
            selectedTab = tab
        }
    }

    private var heroCard: some View {
        GlassCard(padding: 18, radius: 26) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YNX")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(YNXTheme.ink)
                        Text("Klein blue testnet app")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(YNXTheme.klein)
                    }
                    Spacer()
                    StatusPill(label: "TESTNET", color: .orange, systemImage: "testtube.2")
                }

                Text("Real endpoints, real policy issuance, real session authorization, and real transaction broadcast.")
                    .font(.callout)
                    .foregroundStyle(YNXTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    StatusPill(label: "\(YNX.denom)", color: YNXTheme.klein, systemImage: "diamond.fill")
                    StatusPill(label: "No mainnet value", color: .orange, systemImage: "exclamationmark.triangle.fill")
                }
            }
        }
        .offset(y: heroLift ? -3 : 0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                heroLift = true
            }
        }
    }

    private var serviceStrip: some View {
        GlassCard(padding: 14, radius: 22) {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(
                    title: "Service mesh",
                    subtitle: "Tap refresh in Network for a full probe."
                )
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.endpoints) { endpoint in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(endpoint.health.tint)
                                    .frame(width: 7, height: 7)
                                Text(endpoint.kind.rawValue)
                                    .font(.caption2.weight(.semibold))
                                Text(endpoint.health.label)
                                    .font(.caption2.monospaced().weight(.semibold))
                                    .foregroundStyle(endpoint.health.tint)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(YNXTheme.paper, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(endpoint.health.tint.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }

    private var blockCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                LivePulse(symbol: "cube.transparent", color: YNXTheme.klein)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Latest block")
                        .font(.subheadline.weight(.semibold))
                    Text(viewModel.latestBlockHeight)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(YNXTheme.klein)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: viewModel.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(YNXTheme.klein, in: Circle())
                        .foregroundStyle(.white)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }
}

private struct DashboardActionTile: View {
    let title: String
    let detail: String
    let symbol: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(accent.opacity(0.11), in: Circle())

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(YNXTheme.ink)
                    .lineLimit(1)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(YNXTheme.muted)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .background(YNXTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accent.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct LivePulse: View {
    let symbol: String
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 1)
                .scaleEffect(pulse ? 1.35 : 0.84)
                .opacity(pulse ? 0.08 : 0.78)
            Circle()
                .fill(color.opacity(0.12))
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 52, height: 52)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
