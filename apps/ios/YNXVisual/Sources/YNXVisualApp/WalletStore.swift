import CryptoKit
import Foundation
import Security

struct YNXWallet: Equatable {
    let name: String
    let address: String
    let createdAt: Date
    let isTestnetProfile: Bool
}

@MainActor
final class WalletStore: ObservableObject {
    @Published private(set) var wallet: YNXWallet?
    @Published var balanceText = "Not loaded"
    @Published var balanceStatus = "Open Wallet to refresh balance."
    @Published var isRefreshingBalance = false
    @Published var lastPreparedTransaction: PreparedTransaction?
    @Published var lastEncryptedMessage: EncryptedMessage?
    @Published var lastAIJob: LiveAIJob?
    @Published var dappPermissions: [DAppPermission] = []
    @Published var sessionPolicies: [Web4SessionPolicy] = []
    @Published var liveActionStatus = "Ready for live testnet actions."
    @Published var isRunningLiveAction = false
    @Published var broadcastStatus = "Ready to broadcast a signed testnet transaction."
    @Published var isBroadcasting = false
    @Published var lastBroadcastResult: BroadcastResult?
    @Published var thirdPartyStatus = "Ready to test any third-party API."
    @Published var thirdPartyAuditTrail = ""

    private let seedKey = "com.ynxweb4.ynx.wallet.seed"

    init() {
        loadWallet()
    }

    var shortAddress: String {
        guard let address = wallet?.address, address.count > 14 else { return wallet?.address ?? "No wallet" }
        return "\(address.prefix(9))...\(address.suffix(6))"
    }

    func createWallet() {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { return }
        let seed = Data(bytes)
        KeychainStore.save(seed, key: seedKey)
        wallet = makeWallet(seed: seed)
        Task { await refreshBalance() }
    }

    func importWallet(seedPhrase: String) {
        let normalized = seedPhrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return }
        let seed = Data(SHA256.hash(data: Data(normalized.utf8)))
        KeychainStore.save(seed, key: seedKey)
        wallet = makeWallet(seed: seed)
        Task { await refreshBalance() }
    }

    func forgetWallet() {
        KeychainStore.delete(key: seedKey)
        wallet = nil
        balanceText = "Not loaded"
        balanceStatus = "Open Wallet to refresh balance."
        lastPreparedTransaction = nil
        lastEncryptedMessage = nil
        lastAIJob = nil
        dappPermissions = []
        sessionPolicies = []
        liveActionStatus = "Ready for live testnet actions."
        broadcastStatus = "Ready to broadcast a signed testnet transaction."
        lastBroadcastResult = nil
    }

    func prepareTransfer(to recipient: String, amount: String, memo: String) {
        let fee = Decimal(string: "0.0025") ?? 0
        let parsed = Decimal(string: amount) ?? 0
        lastPreparedTransaction = PreparedTransaction(
            id: UUID().uuidString,
            from: wallet?.address ?? "No wallet",
            to: recipient,
            amount: amount,
            estimatedFee: "\(fee)",
            total: "\(parsed + fee)",
            memo: memo,
            status: "Ready for review",
            risk: recipient.hasPrefix("ynx1") ? "Normal" : "Recipient prefix warning"
        )
    }

    func encryptMessage(_ message: String, recipient: String) {
        let digest = SHA256.hash(data: Data("\(recipient)|\(message)".utf8))
        let payload = digest.map { String(format: "%02x", $0) }.joined()
        lastEncryptedMessage = EncryptedMessage(
            id: UUID().uuidString,
            recipient: recipient,
            preview: String(payload.prefix(48)),
            status: "Encrypted locally"
        )
    }

    func grantDAppPermission(origin: String, scopes: [String]) {
        let permission = DAppPermission(
            id: UUID().uuidString,
            origin: origin,
            scopes: scopes,
            grantedAt: Date()
        )
        dappPermissions.removeAll { $0.origin == origin }
        dappPermissions.insert(permission, at: 0)
    }

    func revokePermission(_ permission: DAppPermission) {
        dappPermissions.removeAll { $0.id == permission.id }
    }

    func issueLocalSessionPolicy(spendLimit: String, duration: String, actions: [String]) {
        let policy = Web4SessionPolicy(
            id: "policy_\(UUID().uuidString.prefix(8))",
            spendLimit: spendLimit,
            duration: duration,
            actions: actions,
            status: "Local draft"
        )
        sessionPolicies.insert(policy, at: 0)
    }

    func issueLiveSessionPolicy(spendLimit: String, actions: [String]) async {
        guard let address = wallet?.address else {
            liveActionStatus = "Create a wallet before issuing a Web4 policy."
            return
        }

        isRunningLiveAction = true
        defer { isRunningLiveAction = false }

        do {
            let policyResult = try await YNXLiveAPI.createPolicy(owner: address, spendLimit: spendLimit, actions: actions)
            let sessionResult = try await YNXLiveAPI.issueSession(policyID: policyResult.policy.policyID, ownerSecret: policyResult.ownerSecret)
            let policy = Web4SessionPolicy(
                id: policyResult.policy.policyID,
                spendLimit: spendLimit,
                duration: sessionResult.session.expiresAt,
                actions: actions,
                status: "Live \(sessionResult.session.status)",
                sessionID: sessionResult.session.sessionID,
                sessionToken: sessionResult.token,
                ownerSecret: policyResult.ownerSecret
            )
            sessionPolicies.insert(policy, at: 0)
            liveActionStatus = "Live Web4 policy and session issued: \(short(policy.id))."
        } catch {
            liveActionStatus = "Web4 session failed: \(error.localizedDescription)"
        }
    }

    func createLiveAIJob() async {
        guard let address = wallet?.address else {
            liveActionStatus = "Create a wallet before creating an AI job."
            return
        }

        isRunningLiveAction = true
        defer { isRunningLiveAction = false }

        do {
            let sessionPolicy: Web4SessionPolicy
            if let existing = sessionPolicies.first(where: { $0.sessionToken != nil && $0.actions.contains("ai.job.create") }) {
                sessionPolicy = existing
            } else {
                let policyResult = try await YNXLiveAPI.createPolicy(owner: address, spendLimit: "10", actions: ["ai.job.create"])
                let sessionResult = try await YNXLiveAPI.issueSession(policyID: policyResult.policy.policyID, ownerSecret: policyResult.ownerSecret)
                sessionPolicy = Web4SessionPolicy(
                    id: policyResult.policy.policyID,
                    spendLimit: "10",
                    duration: sessionResult.session.expiresAt,
                    actions: ["ai.job.create"],
                    status: "Live \(sessionResult.session.status)",
                    sessionID: sessionResult.session.sessionID,
                    sessionToken: sessionResult.token,
                    ownerSecret: policyResult.ownerSecret
                )
                sessionPolicies.insert(sessionPolicy, at: 0)
            }

            guard let token = sessionPolicy.sessionToken else {
                liveActionStatus = "No live session token available for AI job."
                return
            }
            let job = try await YNXLiveAPI.createAIJob(creator: address, policyID: sessionPolicy.id, sessionToken: token)
            lastAIJob = job
            liveActionStatus = "Live AI job created: \(short(job.jobID))."
        } catch {
            liveActionStatus = "AI job failed: \(error.localizedDescription)"
        }
    }

    func broadcastSignedTransaction(txBytesBase64: String, mode: BroadcastMode) async {
        let txBytes = txBytesBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !txBytes.isEmpty else {
            broadcastStatus = "Paste signed tx_bytes before broadcasting."
            return
        }

        isBroadcasting = true
        defer { isBroadcasting = false }

        do {
            let result = try await YNXLiveAPI.broadcastSignedTransaction(txBytesBase64: txBytes, mode: mode)
            lastBroadcastResult = result
            if result.code == 0 {
                broadcastStatus = "Broadcast accepted by YNX REST: \(short(result.txhash))."
                await refreshBalance()
            } else {
                broadcastStatus = "Broadcast returned code \(result.code): \(result.rawLog)"
            }
        } catch {
            broadcastStatus = "Broadcast failed: \(error.localizedDescription)"
        }
    }

    func refreshBalance() async {
        guard let address = wallet?.address,
              let url = URL(string: "https://rest.ynxweb4.com/cosmos/bank/v1beta1/balances/\(address)")
        else {
            balanceText = "No wallet"
            balanceStatus = "Create a wallet before checking balance."
            return
        }

        isRefreshingBalance = true
        defer { isRefreshingBalance = false }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(statusCode) else {
                balanceText = "Unavailable"
                balanceStatus = "Balance endpoint returned HTTP \(statusCode)."
                return
            }
            let decoded = try JSONDecoder().decode(BankBalancesResponse.self, from: data)
            let coin = preferredCoin(from: decoded.balances)
            balanceText = formatBalance(coin?.amount ?? "0", denom: coin?.denom ?? YNX.denom)
            balanceStatus = "Updated from YNX REST."
        } catch {
            balanceText = "Unavailable"
            balanceStatus = "Balance refresh failed: \(error.localizedDescription)"
        }
    }

    func testThirdPartyAPI(serviceURL: String, action: String, amount: String) async {
        guard let address = wallet?.address else {
            thirdPartyStatus = "Create a wallet before testing third-party APIs."
            return
        }

        guard let host = URL(string: serviceURL)?.host?.lowercased(), !host.isEmpty else {
            thirdPartyStatus = "Enter a valid service URL."
            return
        }

        isRunningLiveAction = true
        defer { isRunningLiveAction = false }

        do {
            let trimmedAction = action.trimmingCharacters(in: .whitespacesAndNewlines)
            let effectiveAction = trimmedAction.isEmpty ? "service.invoke" : trimmedAction

            let sessionPolicy: Web4SessionPolicy
            if let existing = sessionPolicies.first(where: {
                ($0.sessionToken != nil) && $0.actions.contains(effectiveAction)
            }) {
                sessionPolicy = existing
            } else {
                let policyResult = try await YNXLiveAPI.createPolicy(
                    owner: address,
                    spendLimit: "100",
                    actions: [effectiveAction],
                    serviceHosts: [host]
                )
                let sessionResult = try await YNXLiveAPI.issueSession(policyID: policyResult.policy.policyID, ownerSecret: policyResult.ownerSecret)
                sessionPolicy = Web4SessionPolicy(
                    id: policyResult.policy.policyID,
                    spendLimit: "100",
                    duration: sessionResult.session.expiresAt,
                    actions: [effectiveAction],
                    status: "Live \(sessionResult.session.status)",
                    sessionID: sessionResult.session.sessionID,
                    sessionToken: sessionResult.token,
                    ownerSecret: policyResult.ownerSecret
                )
                sessionPolicies.insert(sessionPolicy, at: 0)
            }

            guard let token = sessionPolicy.sessionToken else {
                thirdPartyStatus = "No live session token available."
                return
            }

            let authorization = try await YNXLiveAPI.authorizeThirdParty(
                policyID: sessionPolicy.id,
                sessionToken: token,
                action: effectiveAction,
                serviceURL: serviceURL,
                amount: amount,
                consume: false
            )
            let consumedAuthorization = try await YNXLiveAPI.authorizeThirdParty(
                policyID: sessionPolicy.id,
                sessionToken: token,
                action: effectiveAction,
                serviceURL: serviceURL,
                amount: amount,
                consume: true
            )
            let preview = try await YNXLiveAPI.fetchThirdPartyPreview(serviceURL: serviceURL)
            let audits = try await YNXLiveAPI.fetchWeb4Audit(limit: 3)
            thirdPartyAuditTrail = audits.map { "\($0.event) @ \($0.createdAt)" }.joined(separator: "\n")
            thirdPartyStatus = "Dry-run + consumed authorization passed for \(authorization.action) on \(host). Remaining ops: \(consumedAuthorization.remainingOps ?? 0). Preview: \(preview)"
        } catch {
            thirdPartyStatus = "Third-party test failed: \(error.localizedDescription)"
            thirdPartyAuditTrail = ""
        }
    }

    private func loadWallet() {
        guard let seed = KeychainStore.load(key: seedKey) else { return }
        wallet = makeWallet(seed: seed)
        Task { await refreshBalance() }
    }

    private func makeWallet(seed: Data) -> YNXWallet {
        let digest = SHA256.hash(data: seed)
        let addressBytes = Array(digest.prefix(20))
        return YNXWallet(
            name: "YNX Testnet Wallet",
            address: Bech32.encode(hrp: "ynx", bytes: addressBytes) ?? "ynx1address_unavailable",
            createdAt: Date(),
            isTestnetProfile: true
        )
    }

    private func short(_ value: String) -> String {
        guard value.count > 16 else { return value }
        return "\(value.prefix(8))...\(value.suffix(6))"
    }
}

private struct BankBalancesResponse: Decodable {
    let balances: [Coin]

    struct Coin: Decodable {
        let denom: String
        let amount: String
    }
}

private func preferredCoin(from balances: [BankBalancesResponse.Coin]) -> BankBalancesResponse.Coin? {
    let preferred = [YNX.denom, "u\(YNX.denom)", "a\(YNX.denom)"]
    for denom in preferred {
        if let coin = balances.first(where: { $0.denom.lowercased() == denom.lowercased() }) {
            return coin
        }
    }
    return balances.first
}

private func formatBalance(_ amount: String, denom: String) -> String {
    guard let decimal = Decimal(string: amount) else { return amount }
    let normalizedDenom = denom.lowercased()
    let scale: Decimal
    if normalizedDenom.hasPrefix("u") {
        scale = Decimal(1_000_000)
    } else if normalizedDenom.hasPrefix("a") {
        scale = Decimal(1_000_000_000_000_000_000)
    } else {
        scale = Decimal(1)
    }
    let displayAmount = decimal / scale
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 6
    formatter.minimumFractionDigits = 0
    return formatter.string(from: displayAmount as NSDecimalNumber) ?? amount
}

enum Bech32 {
    private static let charset = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")

    static func encode(hrp: String, bytes: [UInt8]) -> String? {
        guard let data = convertBits(bytes, from: 8, to: 5, pad: true) else { return nil }
        let checksum = createChecksum(hrp: hrp, data: data)
        let combined = data + checksum
        let payload = combined.compactMap { value -> Character? in
            guard Int(value) < charset.count else { return nil }
            return charset[Int(value)]
        }
        guard payload.count == combined.count else { return nil }
        return "\(hrp)1\(String(payload))"
    }

    private static func createChecksum(hrp: String, data: [UInt8]) -> [UInt8] {
        let values = hrpExpand(hrp) + data + Array(repeating: 0, count: 6)
        let polymod = polymod(values) ^ 1
        return (0..<6).map { index in
            UInt8((polymod >> (5 * (5 - index))) & 31)
        }
    }

    private static func hrpExpand(_ hrp: String) -> [UInt8] {
        let scalars = hrp.unicodeScalars.map { UInt8($0.value) }
        return scalars.map { $0 >> 5 } + [0] + scalars.map { $0 & 31 }
    }

    private static func polymod(_ values: [UInt8]) -> Int {
        let generators = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
        var checksum = 1
        for value in values {
            let top = checksum >> 25
            checksum = ((checksum & 0x1ffffff) << 5) ^ Int(value)
            for index in 0..<5 where ((top >> index) & 1) == 1 {
                checksum ^= generators[index]
            }
        }
        return checksum
    }

    private static func convertBits(_ data: [UInt8], from: Int, to: Int, pad: Bool) -> [UInt8]? {
        var accumulator = 0
        var bits = 0
        let maxValue = (1 << to) - 1
        let maxAccumulator = (1 << (from + to - 1)) - 1
        var result: [UInt8] = []

        for value in data {
            guard (Int(value) >> from) == 0 else { return nil }
            accumulator = ((accumulator << from) | Int(value)) & maxAccumulator
            bits += from
            while bits >= to {
                bits -= to
                result.append(UInt8((accumulator >> bits) & maxValue))
            }
        }

        if pad {
            if bits > 0 {
                result.append(UInt8((accumulator << (to - bits)) & maxValue))
            }
        } else if bits >= from || ((accumulator << (to - bits)) & maxValue) != 0 {
            return nil
        }

        return result
    }
}

struct PreparedTransaction: Equatable {
    let id: String
    let from: String
    let to: String
    let amount: String
    let estimatedFee: String
    let total: String
    let memo: String
    let status: String
    let risk: String
}

struct EncryptedMessage: Equatable {
    let id: String
    let recipient: String
    let preview: String
    let status: String
}

struct DAppPermission: Identifiable, Equatable {
    let id: String
    let origin: String
    let scopes: [String]
    let grantedAt: Date
}

struct Web4SessionPolicy: Identifiable, Equatable {
    let id: String
    let spendLimit: String
    let duration: String
    let actions: [String]
    let status: String
    let sessionID: String?
    let sessionToken: String?
    let ownerSecret: String?

    init(
        id: String,
        spendLimit: String,
        duration: String,
        actions: [String],
        status: String,
        sessionID: String? = nil,
        sessionToken: String? = nil,
        ownerSecret: String? = nil
    ) {
        self.id = id
        self.spendLimit = spendLimit
        self.duration = duration
        self.actions = actions
        self.status = status
        self.sessionID = sessionID
        self.sessionToken = sessionToken
        self.ownerSecret = ownerSecret
    }
}

enum KeychainStore {
    static func save(_ data: Data, key: String) {
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
