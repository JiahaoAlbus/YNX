import SwiftUI

struct WalletView: View {
    @EnvironmentObject private var walletStore: WalletStore
    @State private var seedPhrase = ""
    @State private var showImport = false

    var body: some View {
        PageContainer {
            ScreenHeader(
                eyebrow: "Public Testnet Entry",
                title: "Wallet & Permissions",
                subtitle: "Create local identity, monitor balance, and manage dApp trust boundaries."
            )
            .staggered(0)

            if let wallet = walletStore.wallet {
                walletCard(wallet)
                    .staggered(1)

                walletActions
                    .staggered(2)

                permissionsCard
                    .staggered(3)

                SecurityCenterView()
                    .staggered(4)

                securityNotice
                    .staggered(5)
            } else {
                onboardingCard
                    .staggered(1)
                importCard
                    .staggered(2)
                securityNotice
                    .staggered(3)
            }
        }
    }

    private func walletCard(_ wallet: YNXWallet) -> some View {
        GlassCard(padding: 18, radius: 26) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    HStack(spacing: 12) {
                        YNXLogoMark(size: 50)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(wallet.name)
                                .font(.headline)
                            Text("Address")
                                .font(.caption)
                                .foregroundStyle(YNXTheme.muted)
                        }
                    }
                    Spacer()
                    StatusPill(label: "TESTNET", color: .orange, systemImage: "testtube.2")
                }

                Text(wallet.address)
                    .font(.callout.monospaced().weight(.semibold))
                    .foregroundStyle(YNXTheme.klein)
                    .lineLimit(2)
                    .textSelection(.enabled)

                HStack {
                    WalletStat(label: "Balance", value: "\(walletStore.balanceText) \(YNX.denom)")
                    WalletStat(label: "Denom", value: YNX.denom)
                }

                HStack(spacing: 8) {
                    SoftActionButton(
                        title: walletStore.isRefreshingBalance ? "Refreshing..." : "Refresh Balance",
                        symbol: "arrow.clockwise",
                        color: YNXTheme.klein,
                        disabled: walletStore.isRefreshingBalance
                    ) {
                        Task { await walletStore.refreshBalance() }
                    }

                    SoftActionButton(
                        title: "Remove Wallet",
                        symbol: "trash",
                        color: .red
                    ) {
                        withAnimation(YNXTheme.standard) {
                            walletStore.forgetWallet()
                        }
                    }
                }

                Text(walletStore.balanceStatus)
                    .font(.caption)
                    .foregroundStyle(YNXTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var onboardingCard: some View {
        GlassCard(padding: 18, radius: 26) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(
                    title: "Create Testnet Wallet",
                    subtitle: "Generate a local encrypted profile for YNX app flows."
                )
                Text("This wallet is for public testnet usage only. Tokens are non-mainnet and for testing transfers, policies, sessions, and API authorization flows.")
                    .font(.callout)
                    .foregroundStyle(YNXTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                FilledActionButton(
                    title: "Create Wallet",
                    symbol: "plus.circle.fill",
                    color: YNXTheme.klein
                ) {
                    withAnimation(YNXTheme.standard) {
                        walletStore.createWallet()
                    }
                }
            }
        }
    }

    private var importCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(YNXTheme.standard) {
                        showImport.toggle()
                    }
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(YNXTheme.klein)
                            .frame(width: 36, height: 36)
                            .background(YNXTheme.klein.opacity(0.1), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Import Existing Seed")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(YNXTheme.ink)
                            Text("Restore local test identity from seed phrase.")
                                .font(.caption)
                                .foregroundStyle(YNXTheme.muted)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: showImport ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(YNXTheme.muted)
                    }
                    .padding(12)
                    .background(YNXTheme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(YNXTheme.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(PressableButtonStyle())

                if showImport {
                    TextField("Seed phrase", text: $seedPhrase, axis: .vertical)
                        .lineLimit(2...4)
                        .ynxNoAutocapitalization()
                        .ynxFieldChrome()

                    FilledActionButton(
                        title: "Import Wallet",
                        symbol: "checkmark.seal.fill",
                        color: YNXTheme.klein,
                        disabled: seedPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        walletStore.importWallet(seedPhrase: seedPhrase)
                        seedPhrase = ""
                    }
                }
            }
        }
    }

    private var walletActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(
                title: "Wallet Shortcuts",
                subtitle: "Frequently used actions for daily testing."
            )
            ActionCard(title: "Receive", detail: walletStore.shortAddress, symbol: "qrcode")
            ActionCard(title: "Session Keys", detail: "Grant bounded AI/Web4 actions.", symbol: "key.radiowaves.forward")
            ActionCard(title: "Browser Permission", detail: "Manage connected dApps from this wallet.", symbol: "safari")
        }
    }

    private var permissionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(
                    title: "dApp Permissions",
                    subtitle: "Per-origin scopes granted from YNX Browser.",
                    trailing: AnyView(
                        StatusPill(label: "\(walletStore.dappPermissions.count)", color: YNXTheme.klein, systemImage: "globe")
                    )
                )

                if walletStore.dappPermissions.isEmpty {
                    Text("No connected dApps yet. Open Browser and connect a site from the shield button.")
                        .font(.callout)
                        .foregroundStyle(YNXTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(walletStore.dappPermissions) { permission in
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .foregroundStyle(YNXTheme.klein)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(permission.origin)
                                    .font(.subheadline.weight(.semibold))
                                Text(permission.scopes.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(YNXTheme.muted)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Button {
                                walletStore.revokePermission(permission)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                        if permission.id != walletStore.dappPermissions.last?.id {
                            Divider().opacity(0.35)
                        }
                    }
                }
            }
        }
    }

    private var securityNotice: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Security boundary")
                    .font(.headline)
                Text("Identity material stays in Keychain. This app is a public testnet client: no mainnet custody, no production-value guarantees, and all policy/session actions should be validated before real deployment.")
                    .font(.callout)
                    .foregroundStyle(YNXTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct WalletStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(YNXTheme.muted)
            Text(value)
                .font(.callout.monospaced().weight(.semibold))
                .foregroundStyle(YNXTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
