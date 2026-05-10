import SwiftUI

struct NetworkView: View {
    @EnvironmentObject private var viewModel: YNXNetworkViewModel

    var body: some View {
        PageContainer {
            HStack(alignment: .top) {
                ScreenHeader(
                    eyebrow: "Live Mesh",
                    title: "Network health",
                    subtitle: "Endpoint checks for the YNX Web4 public testnet."
                )
                Spacer()
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: viewModel.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(PressableButtonStyle())
                .foregroundStyle(YNXTheme.klein)
            }
            .staggered(0)

            if let lastRefresh = viewModel.lastRefresh {
                StatusPill(
                    label: "Updated \(relativeTime(lastRefresh))",
                    color: .green,
                    systemImage: "clock.fill"
                )
                .staggered(1)
            }

            GlassCard {
                VStack(spacing: 13) {
                    ForEach(Array(viewModel.endpoints.enumerated()), id: \.element.id) { index, endpoint in
                        EndpointRow(endpoint: endpoint)
                            .staggered(index + 2)
                        if endpoint.id != viewModel.endpoints.last?.id {
                            Divider().opacity(0.42)
                        }
                    }
                }
            }
            .staggered(2)

            GlassCard {
                VStack(alignment: .leading, spacing: 13) {
                    Text("Canonical facts")
                        .font(.headline)
                    FactRow(label: "Cosmos Chain ID", value: YNX.chainID)
                    FactRow(label: "EVM Chain ID", value: YNX.evmChainID)
                    FactRow(label: "Denom", value: YNX.denom)
                    FactRow(label: "Token status", value: "Testnet only")
                    FactRow(label: "Mainnet", value: "Not live")
                }
            }
            .staggered(3)

            ValidatorsViewContent()
                .staggered(4)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct EndpointRow: View {
    let endpoint: EndpointStatus

    var body: some View {
        Button {} label: {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(endpoint.health.tint.opacity(0.12))
                    Circle()
                        .fill(endpoint.health.tint)
                        .frame(width: 9, height: 9)
                        .shadow(color: endpoint.health.tint.opacity(0.55), radius: 8)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(endpoint.kind.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(YNXTheme.ink)
                    Text(endpoint.kind.displayURL)
                        .font(.caption)
                        .foregroundStyle(YNXTheme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Text(endpoint.health.label)
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(endpoint.health.tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(endpoint.health.tint.opacity(0.1), in: Capsule())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct FactRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.callout)
                .foregroundStyle(YNXTheme.muted)
            Spacer(minLength: 12)
            Text(value)
                .font(.callout.monospaced().weight(.semibold))
                .foregroundStyle(YNXTheme.ink)
                .multilineTextAlignment(.trailing)
                .minimumScaleFactor(0.72)
        }
    }
}
