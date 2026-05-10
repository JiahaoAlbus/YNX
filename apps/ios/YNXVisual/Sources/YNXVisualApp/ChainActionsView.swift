import SwiftUI

enum ChainActionMode: String, CaseIterable, Identifiable {
    case transfer = "Transfer"
    case broadcast = "Broadcast"
    case faucet = "Faucet"
    case message = "Message"
    case session = "Session"
    case thirdParty = "Third-party"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .transfer: "arrow.left.arrow.right"
        case .broadcast: "antenna.radiowaves.left.and.right"
        case .faucet: "drop.fill"
        case .message: "lock.doc.fill"
        case .session: "key.radiowaves.forward"
        case .thirdParty: "bolt.shield.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .transfer:
            "Prepare a transfer draft with fee/risk preview."
        case .broadcast:
            "Submit signed tx bytes to the live REST endpoint."
        case .faucet:
            "Request test tokens for all testnet flows."
        case .message:
            "Create encrypted message envelopes locally."
        case .session:
            "Issue bounded policy + session credentials."
        case .thirdParty:
            "Authorize and test arbitrary third-party APIs."
        }
    }
}

struct ChainActionsView: View {
    @EnvironmentObject private var walletStore: WalletStore
    @Environment(\.openURL) private var openURL
    @State private var recipient = ""
    @State private var amount = ""
    @State private var memo = ""
    @State private var signedTxBytes = ""
    @State private var broadcastMode = BroadcastMode.sync
    @State private var faucetAddress = ""
    @State private var faucetStatus = "Ready to request testnet tokens."
    @State private var isRequestingFaucet = false
    @State private var messageRecipient = ""
    @State private var message = ""
    @State private var spendLimit = "10"
    @State private var sessionDuration = "1 hour"
    @State private var thirdPartyURL = "https://httpbin.org/get"
    @State private var thirdPartyAction = "service.invoke"
    @State private var thirdPartyAmount = "1"
    @Binding var selectedMode: ChainActionMode
    @State private var showReview = false

    var body: some View {
        PageContainer {
            ScreenHeader(
                eyebrow: "Operate YNX",
                title: "Action Flows",
                subtitle: "Structured transaction, faucet, messaging, policy, and third-party service operations."
            )
            .staggered(0)

            modeStrip
                .staggered(1)

            activeCard
                .staggered(2)

            if let tx = walletStore.lastPreparedTransaction {
                preparedTransaction(tx)
                    .staggered(3)
            }

            if let encrypted = walletStore.lastEncryptedMessage {
                encryptedMessage(encrypted)
                    .staggered(4)
            }

            if let job = walletStore.lastAIJob {
                liveAIJob(job)
                    .staggered(5)
            }
        }
        .onAppear {
            if faucetAddress.isEmpty, let address = walletStore.wallet?.address {
                faucetAddress = address
            }
        }
    }

    private var modeStrip: some View {
        GlassCard(padding: 12, radius: 20) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ChainActionMode.allCases) { mode in
                        ModeChip(
                            title: mode.rawValue,
                            symbol: mode.symbol,
                            selected: selectedMode == mode
                        ) {
                            withAnimation(YNXTheme.standard) {
                                selectedMode = mode
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var activeCard: some View {
        switch selectedMode {
        case .transfer:
            transferCard
        case .broadcast:
            broadcastCard
        case .faucet:
            faucetCard
        case .message:
            messageCard
        case .session:
            sessionCard
        case .thirdParty:
            thirdPartyCard
        }
    }

    private var transferCard: some View {
        GlassCard(padding: 18, radius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(
                    title: selectedMode.rawValue,
                    subtitle: selectedMode.subtitle,
                    trailing: AnyView(
                        StatusPill(
                            label: walletStore.wallet == nil ? "No Wallet" : "Wallet Ready",
                            color: walletStore.wallet == nil ? .orange : .green,
                            systemImage: walletStore.wallet == nil ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
                        )
                    )
                )

                TextField("Recipient ynx1...", text: $recipient)
                    .ynxNoAutocapitalization()
                    .ynxFieldChrome()
                TextField("Amount", text: $amount)
                    .ynxFieldChrome()
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                TextField("Memo", text: $memo, axis: .vertical)
                    .lineLimit(1...3)
                    .ynxFieldChrome()

                FilledActionButton(
                    title: "Prepare Transfer Draft",
                    symbol: "checkmark.seal.fill",
                    color: YNXTheme.klein,
                    disabled: walletStore.wallet == nil
                ) {
                    walletStore.prepareTransfer(to: recipient, amount: amount, memo: memo)
                    showReview = true
                }
            }
        }
        .sheet(isPresented: $showReview) {
            if let tx = walletStore.lastPreparedTransaction {
                TransactionReviewSheet(tx: tx)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var broadcastCard: some View {
        GlassCard(padding: 18, radius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(title: selectedMode.rawValue, subtitle: selectedMode.subtitle)

                TextField("Signed tx_bytes base64", text: $signedTxBytes, axis: .vertical)
                    .lineLimit(4...8)
                    .ynxNoAutocapitalization()
                    .ynxFieldChrome()

                Picker("Broadcast mode", selection: $broadcastMode) {
                    ForEach(BroadcastMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                statusMessageCard(
                    walletStore.broadcastStatus,
                    ok: walletStore.broadcastStatus.hasPrefix("Broadcast accepted")
                )

                FilledActionButton(
                    title: walletStore.isBroadcasting ? "Broadcasting..." : "Broadcast to Testnet",
                    symbol: "paperplane.fill",
                    color: YNXTheme.klein,
                    disabled: !canBroadcast || walletStore.isBroadcasting
                ) {
                    Task {
                        await walletStore.broadcastSignedTransaction(
                            txBytesBase64: signedTxBytes,
                            mode: broadcastMode
                        )
                    }
                }

                if let result = walletStore.lastBroadcastResult {
                    broadcastResult(result)
                }
            }
        }
    }

    private var faucetCard: some View {
        GlassCard(padding: 18, radius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(title: selectedMode.rawValue, subtitle: selectedMode.subtitle)

                HStack(spacing: 10) {
                    TextField("Recipient ynx1...", text: $faucetAddress)
                        .ynxNoAutocapitalization()
                        .ynxFieldChrome()
                    Button {
                        if let address = walletStore.wallet?.address {
                            faucetAddress = address
                        }
                    } label: {
                        Image(systemName: "wallet.pass.fill")
                            .font(.headline)
                            .foregroundStyle(YNXTheme.klein)
                            .frame(width: 44, height: 44)
                            .background(YNXTheme.klein.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(walletStore.wallet == nil)
                }

                FilledActionButton(
                    title: isRequestingFaucet ? "Requesting..." : "Request Test Tokens",
                    symbol: isRequestingFaucet ? "arrow.triangle.2.circlepath" : "drop.fill",
                    color: .cyan,
                    disabled: !canRequestFaucet || isRequestingFaucet
                ) {
                    Task { await requestFaucet() }
                }

                SoftActionButton(
                    title: "Open Faucet Website",
                    symbol: "arrow.up.right.square",
                    color: YNXTheme.klein
                ) {
                    openURL(URL(string: "https://faucet.ynxweb4.com")!)
                }

                statusMessageCard(faucetStatus, ok: faucetStatus.hasPrefix("Success"))
            }
        }
    }

    private var messageCard: some View {
        GlassCard(padding: 18, radius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(title: selectedMode.rawValue, subtitle: selectedMode.subtitle)

                TextField("Recipient identity", text: $messageRecipient)
                    .ynxNoAutocapitalization()
                    .ynxFieldChrome()
                TextField("Message", text: $message, axis: .vertical)
                    .lineLimit(3...6)
                    .ynxFieldChrome()

                FilledActionButton(
                    title: "Encrypt Message",
                    symbol: "lock.fill",
                    color: .indigo
                ) {
                    walletStore.encryptMessage(message, recipient: messageRecipient)
                }
            }
        }
    }

    private var sessionCard: some View {
        GlassCard(padding: 18, radius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(title: selectedMode.rawValue, subtitle: selectedMode.subtitle)

                TextField("Spend limit (\(YNX.denom))", text: $spendLimit)
                    .ynxFieldChrome()
                TextField("Session label (optional)", text: $sessionDuration)
                    .ynxFieldChrome()

                ForEach(Array(settlementSteps.enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(YNXTheme.klein, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.subheadline.weight(.semibold))
                            Text(step.detail)
                                .font(.caption)
                                .foregroundStyle(YNXTheme.muted)
                        }
                        Spacer()
                    }
                }

                statusMessageCard(walletStore.liveActionStatus, ok: walletStore.liveActionStatus.hasPrefix("Live"))

                FilledActionButton(
                    title: walletStore.isRunningLiveAction ? "Issuing..." : "Issue Live Session",
                    symbol: "key.fill",
                    color: .green,
                    disabled: walletStore.wallet == nil || walletStore.isRunningLiveAction
                ) {
                    Task {
                        await walletStore.issueLiveSessionPolicy(
                            spendLimit: spendLimit,
                            actions: ["ai.job.create", "ai.job.commit", "ai.job.finalize", "ai.payment.charge"]
                        )
                    }
                }

                FilledActionButton(
                    title: walletStore.isRunningLiveAction ? "Creating..." : "Create Live AI Job",
                    symbol: "cpu.fill",
                    color: YNXTheme.klein,
                    disabled: walletStore.wallet == nil || walletStore.isRunningLiveAction
                ) {
                    Task { await walletStore.createLiveAIJob() }
                }
            }
        }
    }

    private var thirdPartyCard: some View {
        GlassCard(padding: 18, radius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(title: selectedMode.rawValue, subtitle: selectedMode.subtitle)

                TextField("Service URL", text: $thirdPartyURL)
                    .ynxNoAutocapitalization()
                    .ynxFieldChrome()
                TextField("Action", text: $thirdPartyAction)
                    .ynxNoAutocapitalization()
                    .ynxFieldChrome()
                TextField("Amount", text: $thirdPartyAmount)
                    .ynxFieldChrome()
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif

                FilledActionButton(
                    title: walletStore.isRunningLiveAction ? "Testing..." : "Authorize and Test API",
                    symbol: "bolt.shield.fill",
                    color: .teal,
                    disabled: walletStore.wallet == nil || walletStore.isRunningLiveAction
                ) {
                    Task {
                        await walletStore.testThirdPartyAPI(
                            serviceURL: thirdPartyURL,
                            action: thirdPartyAction,
                            amount: thirdPartyAmount
                        )
                    }
                }

                statusMessageCard(
                    walletStore.thirdPartyStatus,
                    ok: walletStore.thirdPartyStatus.contains("passed")
                )

                if !walletStore.thirdPartyAuditTrail.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Latest audit trail")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(YNXTheme.ink)
                        Text(walletStore.thirdPartyAuditTrail)
                            .font(.caption2.monospaced())
                            .foregroundStyle(YNXTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(YNXTheme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(YNXTheme.hairline, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func preparedTransaction(_ tx: PreparedTransaction) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Prepared transaction")
                    .font(.headline)
                FactRow(label: "From", value: short(tx.from))
                FactRow(label: "To", value: short(tx.to))
                FactRow(label: "Amount", value: "\(tx.amount) \(YNX.denom)")
                FactRow(label: "Fee", value: "\(tx.estimatedFee) \(YNX.denom)")
                FactRow(label: "Total", value: "\(tx.total) \(YNX.denom)")
                FactRow(label: "Risk", value: tx.risk)
                FactRow(label: "Status", value: tx.status)
            }
        }
    }

    private func encryptedMessage(_ encrypted: EncryptedMessage) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Encrypted message")
                    .font(.headline)
                FactRow(label: "Recipient", value: short(encrypted.recipient))
                FactRow(label: "Cipher preview", value: encrypted.preview)
                FactRow(label: "Status", value: encrypted.status)
            }
        }
    }

    private func liveAIJob(_ job: LiveAIJob) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Live AI job")
                    .font(.headline)
                FactRow(label: "Job", value: job.jobID)
                FactRow(label: "Status", value: job.status)
                FactRow(label: "Gateway", value: "ai.ynxweb4.com")
            }
        }
    }

    private func broadcastResult(_ result: BroadcastResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FactRow(label: "Tx hash", value: result.txhash)
            FactRow(label: "Code", value: "\(result.code)")
            FactRow(label: "Height", value: result.height)
            FactRow(label: "Log", value: result.rawLog.isEmpty ? "Accepted" : result.rawLog)
        }
        .padding(12)
        .background(YNXTheme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(YNXTheme.hairline, lineWidth: 1)
        )
    }

    private func statusMessageCard(_ text: String, ok: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: ok ? "checkmark.seal.fill" : "info.circle.fill")
                .foregroundStyle(ok ? .green : YNXTheme.klein)
            Text(text)
                .font(.caption)
                .foregroundStyle(YNXTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(YNXTheme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(YNXTheme.hairline, lineWidth: 1)
        )
    }

    private var canRequestFaucet: Bool {
        faucetAddress.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("ynx1")
    }

    private var canBroadcast: Bool {
        !signedTxBytes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func requestFaucet() async {
        let address = faucetAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://faucet.ynxweb4.com/faucet?address=\(encoded)")
        else {
            faucetStatus = "Enter a valid ynx1 testnet address."
            return
        }

        isRequestingFaucet = true
        defer { isRequestingFaucet = false }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            if (200..<300).contains(statusCode) {
                faucetStatus = "Success. Faucet accepted the request for \(short(address))."
                await walletStore.refreshBalance()
            } else if statusCode == 429 || body.lowercased().contains("ip_rate_limited") {
                faucetStatus = "Rate limited by faucet IP policy. Wait a few minutes, then retry. If your wallet already received tokens, tap refresh balance."
            } else {
                faucetStatus = "Faucet returned HTTP \(statusCode): \(body.prefix(140))"
            }
        } catch {
            faucetStatus = "Faucet request failed: \(error.localizedDescription)"
        }
    }

    private func short(_ value: String) -> String {
        guard value.count > 16 else { return value }
        return "\(value.prefix(8))...\(value.suffix(6))"
    }
}

struct TransactionReviewSheet: View {
    let tx: PreparedTransaction
    @Environment(\.dismiss) private var dismiss
    @State private var armed = false

    var body: some View {
        ZStack {
            PhoneBackground()
            VStack(alignment: .leading, spacing: 18) {
                Capsule()
                    .fill(YNXTheme.hairline)
                    .frame(width: 46, height: 5)
                    .frame(maxWidth: .infinity)

                ScreenHeader(
                    eyebrow: "Testnet Review",
                    title: "Review Transfer Draft",
                    subtitle: "Sign with a Cosmos signer, then paste tx_bytes into Broadcast."
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        FactRow(label: "From", value: short(tx.from))
                        FactRow(label: "To", value: short(tx.to))
                        FactRow(label: "Amount", value: "\(tx.amount) \(YNX.denom)")
                        FactRow(label: "Estimated fee", value: "\(tx.estimatedFee) \(YNX.denom)")
                        FactRow(label: "Total", value: "\(tx.total) \(YNX.denom)")
                        FactRow(label: "Risk", value: tx.risk)
                    }
                }

                Toggle("I understand this is a testnet transaction flow", isOn: $armed)
                    .font(.callout.weight(.semibold))

                FilledActionButton(
                    title: "Close Review",
                    symbol: armed ? "checkmark.seal.fill" : "lock.fill",
                    color: YNXTheme.klein,
                    disabled: !armed
                ) {
                    dismiss()
                }

                Spacer()
            }
            .padding(20)
        }
    }

    private func short(_ value: String) -> String {
        guard value.count > 16 else { return value }
        return "\(value.prefix(8))...\(value.suffix(6))"
    }
}
