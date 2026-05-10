import SwiftUI

struct DocsView: View {
    private let docs: [DocLink] = [
        DocLink(title: "Public Testnet Join", detail: "Join YNX v2 and configure endpoints.", symbol: "figure.walk.arrival", url: URL(string: "https://ynxweb4.com/docs/en/public-testnet-join")!),
        DocLink(title: "AI/Web4 Official Demo", detail: "Run policy, session, vault, job, and settlement.", symbol: "sparkles.rectangle.stack", url: URL(string: "https://ynxweb4.com/docs/en/ai-web4-official-demo")!),
        DocLink(title: "Validator Onboarding", detail: "External validator setup and responsibilities.", symbol: "shield.lefthalf.filled", url: URL(string: "https://ynxweb4.com/docs/en/external-validator-onboarding")!),
        DocLink(title: "Universal Bridge Method", detail: "Cross-chain asset onboarding and gateway flow.", symbol: "link.badge.plus", url: URL(string: "https://github.com/JiahaoAlbus/YNX/blob/main/docs/en/UNIVERSAL_BRIDGE_METHOD.md")!),
        DocLink(title: "Web4 API", detail: "Policy-bounded delegation API reference.", symbol: "curlybraces", url: URL(string: "https://ynxweb4.com/docs/en/ynx-v2-web4-api")!),
        DocLink(title: "AI Settlement API", detail: "Job, commit, finalize, and reward settlement.", symbol: "cpu", url: URL(string: "https://ynxweb4.com/docs/en/ynx-v2-ai-settlement-api")!)
    ]

    var body: some View {
        PageContainer {
            ScreenHeader(
                eyebrow: "Canonical Docs",
                title: "Build on YNX",
                subtitle: "Fast native entry points for builders, validators, and AI agent developers."
            )
            .staggered(0)

            VStack(spacing: 11) {
                ForEach(Array(docs.enumerated()), id: \.element.id) { index, item in
                    Link(destination: item.url) {
                        DocCard(item: item)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .staggered(index + 1)
                }
            }
        }
    }
}

struct DocLink: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let symbol: String
    let url: URL
}

struct DocCard: View {
    let item: DocLink

    var body: some View {
        GlassCard(padding: 14, radius: 22) {
            HStack(spacing: 12) {
                Image(systemName: item.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(YNXTheme.klein)
                    .frame(width: 42, height: 42)
                    .background(YNXTheme.klein.opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(YNXTheme.ink)
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(YNXTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(YNXTheme.klein)
            }
        }
    }
}
