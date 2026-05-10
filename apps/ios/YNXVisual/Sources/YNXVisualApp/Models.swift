import Foundation
import SwiftUI

enum YNX {
    static let chainID = "ynx_9102-1"
    static let evmChainID = "9102 / 0x238e"
    static let denom = "anyxt"
    static let validatorTarget = 4
    static let docs = URL(string: "https://ynxweb4.com/docs/en/public-testnet-join")!
    static let github = URL(string: "https://github.com/JiahaoAlbus/YNX")!
}

enum EndpointKind: String, CaseIterable, Identifiable {
    case rpc = "RPC"
    case rest = "REST"
    case evm = "EVM"
    case faucet = "Faucet"
    case indexer = "Indexer"
    case explorer = "Explorer"
    case aiGateway = "AI Gateway"
    case web4Hub = "Web4 Hub"

    var id: String { rawValue }

    var url: URL {
        switch self {
        case .rpc: URL(string: "https://rpc.ynxweb4.com/status")!
        case .rest: URL(string: "https://rest.ynxweb4.com/cosmos/base/tendermint/v1beta1/blocks/latest")!
        case .evm: URL(string: "https://evm.ynxweb4.com")!
        case .faucet: URL(string: "https://faucet.ynxweb4.com/health")!
        case .indexer: URL(string: "https://indexer.ynxweb4.com/ynx/overview")!
        case .explorer: URL(string: "https://explorer.ynxweb4.com")!
        case .aiGateway: URL(string: "https://ai.ynxweb4.com/ready")!
        case .web4Hub: URL(string: "https://web4.ynxweb4.com/ready")!
        }
    }

    var displayURL: String {
        switch self {
        case .rpc: "rpc.ynxweb4.com"
        case .rest: "rest.ynxweb4.com"
        case .evm: "evm.ynxweb4.com"
        case .faucet: "faucet.ynxweb4.com"
        case .indexer: "indexer.ynxweb4.com"
        case .explorer: "explorer.ynxweb4.com"
        case .aiGateway: "ai.ynxweb4.com"
        case .web4Hub: "web4.ynxweb4.com"
        }
    }
}

enum EndpointHealth: Equatable {
    case checking
    case online(Int)
    case slow(Int)
    case reachable(Int)
    case timeout
    case offline(String)

    var label: String {
        switch self {
        case .checking: "Checking"
        case .online(let latency): "Live \(latency) ms"
        case .slow(let latency): "Slow \(latency) ms"
        case .reachable(let latency): "OK \(latency) ms"
        case .timeout: "Timeout"
        case .offline: "Offline"
        }
    }

    var tint: Color {
        switch self {
        case .checking: .secondary
        case .online: .green
        case .slow: .orange
        case .reachable: .green
        case .timeout: .orange
        case .offline: .red
        }
    }
}

struct EndpointStatus: Identifiable, Equatable {
    let kind: EndpointKind
    var health: EndpointHealth
    var id: String { kind.id }
}

struct ValidatorInfo: Identifiable, Hashable {
    let id: String
    let moniker: String
    let votingPower: String
    let commission: String
    let status: String
}

struct SettlementStep: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let symbol: String
}

let settlementSteps: [SettlementStep] = [
    SettlementStep(title: "Owner Policy", detail: "User defines spend, action, and session boundaries.", symbol: "person.badge.key"),
    SettlementStep(title: "Session Key", detail: "Agent receives bounded authority without custody.", symbol: "key.radiowaves.forward"),
    SettlementStep(title: "Vault Budget", detail: "Machine-payment vault funds job execution.", symbol: "creditcard.trianglebadge.exclamationmark"),
    SettlementStep(title: "Agent Job", detail: "Worker commits result hash and proof metadata.", symbol: "cpu"),
    SettlementStep(title: "Settlement", detail: "Reward settles on YNX with inspectable evidence.", symbol: "checkmark.seal")
]
