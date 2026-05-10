import Foundation

enum YNXLiveAPI {
    static func createPolicy(owner: String, spendLimit: String, actions: [String], serviceHosts: [String] = []) async throws -> LivePolicyResult {
        var payload: [String: Any] = [
            "owner": owner,
            "name": "ynx-ios-\(Int(Date().timeIntervalSince1970))",
            "allowed_actions": actions,
            "max_total_spend": Decimal(string: spendLimit).map(NSDecimalNumber.init(decimal:)) ?? 10,
            "max_daily_spend": Decimal(string: spendLimit).map(NSDecimalNumber.init(decimal:)) ?? 10,
            "session_ttl_sec": 900
        ]
        if !serviceHosts.isEmpty {
            payload["allowed_service_hosts"] = serviceHosts
        }
        let data = try await postJSON(url: URL(string: "https://web4.ynxweb4.com/web4/policies")!, payload: payload)
        let decoded = try JSONDecoder().decode(LivePolicyResponse.self, from: data)
        guard decoded.ok, let policy = decoded.policy, let ownerSecret = decoded.ownerSecret else {
            throw LiveAPIError.server(decoded.error ?? "policy_create_failed")
        }
        return LivePolicyResult(policy: policy, ownerSecret: ownerSecret)
    }

    static func issueSession(policyID: String, ownerSecret: String) async throws -> LiveSessionResult {
        let data = try await postJSON(
            url: URL(string: "https://web4.ynxweb4.com/web4/policies/\(policyID)/sessions")!,
            payload: [:],
            headers: ["x-ynx-owner": ownerSecret]
        )
        let decoded = try JSONDecoder().decode(LiveSessionResponse.self, from: data)
        guard decoded.ok, let session = decoded.session, let token = decoded.token else {
            throw LiveAPIError.server(decoded.error ?? "session_issue_failed")
        }
        return LiveSessionResult(session: session, token: token)
    }

    static func createAIJob(creator: String, policyID: String, sessionToken: String) async throws -> LiveAIJob {
        let payload: [String: Any] = [
            "creator": creator,
            "worker": "ynx-ios-app",
            "policy_id": policyID,
            "reward": "1",
            "stake": "0",
            "input_uri": "ynx://ios/live-job/\(Int(Date().timeIntervalSince1970))"
        ]
        let data = try await postJSON(
            url: URL(string: "https://ai.ynxweb4.com/ai/jobs")!,
            payload: payload,
            headers: ["x-ynx-session": sessionToken]
        )
        let decoded = try JSONDecoder().decode(LiveAIJobResponse.self, from: data)
        guard decoded.ok, let job = decoded.job else {
            throw LiveAPIError.server(decoded.error ?? "job_create_failed")
        }
        return job
    }

    static func fetchAIStats() async throws -> LiveAIStats {
        var request = URLRequest(url: URL(string: "https://ai.ynxweb4.com/ai/stats")!)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw LiveAPIError.server("HTTP \(status)") }
        return try JSONDecoder().decode(LiveAIStats.self, from: data)
    }

    static func broadcastSignedTransaction(txBytesBase64: String, mode: BroadcastMode) async throws -> BroadcastResult {
        let payload: [String: Any] = [
            "tx_bytes": txBytesBase64,
            "mode": mode.apiValue
        ]
        let data = try await postJSON(url: URL(string: "https://rest.ynxweb4.com/cosmos/tx/v1beta1/txs")!, payload: payload)
        let decoded = try JSONDecoder().decode(BroadcastResponse.self, from: data)
        return decoded.txResponse
    }

    static func authorizeThirdParty(policyID: String, sessionToken: String, action: String, serviceURL: String, amount: String, consume: Bool = true) async throws -> ThirdPartyAuthorization {
        guard let url = URL(string: serviceURL), let host = url.host else {
            throw LiveAPIError.server("invalid_service_url")
        }
        let payload: [String: Any] = [
            "policy_id": policyID,
            "action": action,
            "amount": Decimal(string: amount).map(NSDecimalNumber.init(decimal:)) ?? 1,
            "resource_host": host.lowercased(),
            "resource": serviceURL,
            "consume": consume
        ]
        let data = try await postJSON(
            url: URL(string: "https://web4.ynxweb4.com/web4/authorize")!,
            payload: payload,
            headers: ["x-ynx-session": sessionToken]
        )
        let decoded = try JSONDecoder().decode(ThirdPartyAuthorization.self, from: data)
        guard decoded.ok else {
            throw LiveAPIError.server("third_party_authorization_failed")
        }
        return decoded
    }

    static func fetchThirdPartyPreview(serviceURL: String) async throws -> String {
        guard let url = URL(string: serviceURL) else {
            throw LiveAPIError.server("invalid_service_url")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<500).contains(status) else {
            throw LiveAPIError.server("HTTP \(status)")
        }
        let text = String(data: data, encoding: .utf8) ?? "<binary response>"
        return String(text.prefix(280))
    }

    static func fetchWeb4Audit(limit: Int = 3) async throws -> [Web4AuditItem] {
        var components = URLComponents(string: "https://web4.ynxweb4.com/web4/audit")!
        components.queryItems = [URLQueryItem(name: "limit", value: String(max(1, min(20, limit))))]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw LiveAPIError.server("HTTP \(status)")
        }
        let decoded = try JSONDecoder().decode(Web4AuditResponse.self, from: data)
        return decoded.items
    }

    private static func postJSON(url: URL, payload: [String: Any], headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LiveAPIError.server("HTTP \(status): \(body.prefix(140))")
        }
        return data
    }
}

enum BroadcastMode: String, CaseIterable, Identifiable {
    case sync
    case async
    case block

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sync: "SYNC"
        case .async: "ASYNC"
        case .block: "BLOCK"
        }
    }

    var apiValue: String {
        switch self {
        case .sync: "BROADCAST_MODE_SYNC"
        case .async: "BROADCAST_MODE_ASYNC"
        case .block: "BROADCAST_MODE_BLOCK"
        }
    }
}

enum LiveAPIError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case .server(let message): message
        }
    }
}

struct LivePolicyResult {
    let policy: LiveWeb4Policy
    let ownerSecret: String
}

struct LiveSessionResult {
    let session: LiveWeb4Session
    let token: String
}

private struct LivePolicyResponse: Decodable {
    let ok: Bool
    let policy: LiveWeb4Policy?
    let ownerSecret: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, policy, error
        case ownerSecret = "owner_secret"
    }
}

private struct LiveSessionResponse: Decodable {
    let ok: Bool
    let session: LiveWeb4Session?
    let token: String?
    let error: String?
}

private struct LiveAIJobResponse: Decodable {
    let ok: Bool
    let job: LiveAIJob?
    let error: String?
}

struct LiveWeb4Policy: Decodable, Equatable {
    let policyID: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case policyID = "policy_id"
        case status
    }
}

struct LiveWeb4Session: Decodable, Equatable {
    let sessionID: String
    let status: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case status
        case expiresAt = "expires_at"
    }
}

struct LiveAIJob: Decodable, Equatable {
    let jobID: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case jobID = "job_id"
        case status
    }
}

struct LiveAIStats: Decodable, Equatable {
    let ok: Bool
    let chainID: String
    let enforcePolicy: Bool
    let totalJobs: Int
    let totalVaults: Int
    let totalPayments: Int

    enum CodingKeys: String, CodingKey {
        case ok
        case chainID = "chain_id"
        case enforcePolicy = "enforce_policy"
        case totalJobs = "total_jobs"
        case totalVaults = "total_vaults"
        case totalPayments = "total_payments"
    }
}

struct ThirdPartyAuthorization: Decodable, Equatable {
    let ok: Bool
    let policyID: String
    let sessionID: String
    let action: String
    let consumed: Bool
    let remainingOps: Int?
    let remainingSpend: Double?
    let sessionExpiresAt: String

    enum CodingKeys: String, CodingKey {
        case ok
        case policyID = "policy_id"
        case sessionID = "session_id"
        case action
        case consumed
        case remainingOps = "remaining_ops"
        case remainingSpend = "remaining_spend"
        case sessionExpiresAt = "session_expires_at"
    }
}

struct Web4AuditItem: Decodable, Equatable {
    let auditID: String
    let event: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case auditID = "audit_id"
        case event
        case createdAt = "created_at"
    }
}

private struct Web4AuditResponse: Decodable {
    let ok: Bool
    let items: [Web4AuditItem]
}

private struct BroadcastResponse: Decodable {
    let txResponse: BroadcastResult

    enum CodingKeys: String, CodingKey {
        case txResponse = "tx_response"
    }
}

struct BroadcastResult: Decodable, Equatable {
    let height: String
    let txhash: String
    let code: Int
    let rawLog: String

    enum CodingKeys: String, CodingKey {
        case height
        case txhash
        case code
        case rawLog = "raw_log"
    }
}
