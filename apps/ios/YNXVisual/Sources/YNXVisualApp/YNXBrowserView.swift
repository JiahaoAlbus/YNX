import SwiftUI
import WebKit

@MainActor
final class BrowserController: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    @Published var title = "YNX Browser"
    @Published var host = "ynxweb4.com"
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var encryptedRouteEnabled = true
    @Published var lastSecurityEvent = "HTTPS-only route enabled"

    override init() {
        let configuration = WKWebViewConfiguration()
        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true
        #endif
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        self.webView.navigationDelegate = self
        #if os(iOS)
        self.webView.scrollView.contentInsetAdjustmentBehavior = .never
        #endif
    }

    func load(_ url: URL) {
        host = url.host ?? url.absoluteString
        webView.load(URLRequest(url: url))
    }

    func reload() {
        webView.reload()
    }

    func goBack() {
        if webView.canGoBack { webView.goBack() }
    }

    func goForward() {
        if webView.canGoForward { webView.goForward() }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        syncState()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard encryptedRouteEnabled,
              let url = navigationAction.request.url,
              url.scheme?.lowercased() == "http",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return .allow
        }

        components.scheme = "https"
        if let upgraded = components.url {
            lastSecurityEvent = "Upgraded \(url.host ?? "site") to HTTPS"
            load(upgraded)
        } else {
            lastSecurityEvent = "Blocked insecure HTTP navigation"
        }
        return .cancel
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        syncState()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        syncState()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        syncState()
    }

    private func syncState() {
        title = webView.title?.isEmpty == false ? webView.title! : "YNX Browser"
        host = webView.url?.host ?? host
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        if webView.url?.scheme?.lowercased() == "https" {
            lastSecurityEvent = encryptedRouteEnabled ? "Encrypted HTTPS route active" : "HTTPS loaded"
        }
    }
}

struct YNXBrowserView: View {
    @EnvironmentObject private var walletStore: WalletStore
    @StateObject private var browser = BrowserController()
    @State private var urlText = "https://ynxweb4.com"
    @State private var currentURL = URL(string: "https://ynxweb4.com")!
    @State private var selectedShortcut = 0
    @State private var showConnect = false
    @State private var showMenu = false

    private let shortcuts: [(String, String, URL)] = [
        ("Portal", "ynxweb4.com", URL(string: "https://ynxweb4.com")!),
        ("Explorer", "explorer.ynxweb4.com", URL(string: "https://explorer.ynxweb4.com")!),
        ("Faucet", "faucet.ynxweb4.com", URL(string: "https://faucet.ynxweb4.com")!),
        ("AI Gateway", "ai.ynxweb4.com", URL(string: "https://ai.ynxweb4.com")!),
        ("Web4 Hub", "web4.ynxweb4.com", URL(string: "https://web4.ynxweb4.com")!)
    ]

    var body: some View {
        ZStack {
            PhoneBackground()

            BrowserWebView(controller: browser)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.68), lineWidth: 1))
                .shadow(color: YNXTheme.klein.opacity(0.12), radius: 18, x: 0, y: 10)
                .padding(.horizontal, 10)
                .padding(.top, 54)
                .padding(.bottom, 164)

            VStack(spacing: 0) {
                topStatusBar
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                Spacer()
                browserMenu
                    .padding(.horizontal, 14)
                    .opacity(showMenu ? 1 : 0)
                    .offset(y: showMenu ? 0 : 16)
                    .animation(YNXTheme.standard, value: showMenu)
                bottomBrowserBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 92)
            }
        }
        .onAppear {
            browser.load(currentURL)
        }
        .sheet(isPresented: $showConnect) {
            DAppPermissionSheet(origin: browser.host)
                .environmentObject(walletStore)
                .presentationDetents([.medium])
        }
    }

    private var topStatusBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
                Text(browser.host)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(YNXTheme.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            StatusPill(
                label: browser.encryptedRouteEnabled ? "HTTPS-ONLY" : "TESTNET DAPP",
                color: browser.encryptedRouteEnabled ? .green : .orange,
                systemImage: browser.encryptedRouteEnabled ? "lock.shield.fill" : "testtube.2"
            )
        }
    }

    private var bottomBrowserBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 9) {
                browserButton("chevron.left", enabled: browser.canGoBack) { browser.goBack() }
                browserButton("chevron.right", enabled: browser.canGoForward) { browser.goForward() }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(YNXTheme.muted)
                    TextField("Search or enter address", text: $urlText)
                        .font(.callout)
                        .textFieldStyle(.plain)
                        .ynxNoAutocapitalization()
                        #if os(iOS)
                        .keyboardType(.URL)
                        .submitLabel(.go)
                        #endif
                        .onSubmit { openTypedURL() }
                    Button {
                        openTypedURL()
                    } label: {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .foregroundStyle(YNXTheme.klein)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(.white.opacity(0.86), in: Capsule())
                .overlay(Capsule().stroke(YNXTheme.hairline, lineWidth: 1))

                browserButton(browser.isLoading ? "xmark" : "arrow.clockwise", enabled: true) {
                    browser.reload()
                }
                browserButton("shield.lefthalf.filled", enabled: true) {
                    showConnect = true
                }
                browserButton("ellipsis", enabled: true) {
                    withAnimation(YNXTheme.standard) { showMenu.toggle() }
                }
            }
            .padding(8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.72), lineWidth: 1))
            .shadow(color: YNXTheme.klein.opacity(0.18), radius: 24, x: 0, y: 12)
        }
    }

    private var browserMenu: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Quick open")
                    .font(.headline)
                Spacer()
                Text(walletStore.wallet == nil ? "No wallet" : walletStore.shortAddress)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(YNXTheme.muted)
            }
            HStack(spacing: 10) {
                Image(systemName: browser.encryptedRouteEnabled ? "lock.shield.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(browser.encryptedRouteEnabled ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Encrypted route")
                        .font(.subheadline.weight(.semibold))
                    Text(browser.lastSecurityEvent)
                        .font(.caption)
                        .foregroundStyle(YNXTheme.muted)
                        .lineLimit(2)
                }
                Spacer()
                Toggle("", isOn: $browser.encryptedRouteEnabled)
                    .labelsHidden()
            }
            .padding(12)
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(Array(shortcuts.enumerated()), id: \.offset) { index, shortcut in
                    Button {
                        selectedShortcut = index
                        currentURL = shortcut.2
                        urlText = shortcut.2.absoluteString
                        browser.load(shortcut.2)
                        showMenu = false
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shortcut.0)
                                .font(.caption.weight(.bold))
                            Text(shortcut.1)
                                .font(.caption2)
                                .foregroundStyle(selectedShortcut == index ? .white.opacity(0.75) : YNXTheme.muted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(selectedShortcut == index ? YNXTheme.klein : .white.opacity(0.72), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .foregroundStyle(selectedShortcut == index ? .white : YNXTheme.ink)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.72), lineWidth: 1))
    }

    private func browserButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(enabled ? YNXTheme.klein : YNXTheme.muted.opacity(0.45))
                .frame(width: 34, height: 34)
                .background(.white.opacity(enabled ? 0.72 : 0.38), in: Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
    }

    private func openTypedURL() {
        let raw = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        var normalized = raw.hasPrefix("http://") || raw.hasPrefix("https://") ? raw : "https://\(raw)"
        if browser.encryptedRouteEnabled, normalized.hasPrefix("http://") {
            normalized = "https://" + normalized.dropFirst("http://".count)
            browser.lastSecurityEvent = "Upgraded typed URL to HTTPS"
        }
        if let url = URL(string: normalized) {
            currentURL = url
            urlText = normalized
            browser.load(url)
        }
    }
}

struct DAppPermissionSheet: View {
    @EnvironmentObject private var walletStore: WalletStore
    @Environment(\.dismiss) private var dismiss
    let origin: String
    @State private var account = true
    @State private var signatures = false
    @State private var encryptedMessages = true
    @State private var sessions = false

    var body: some View {
        ZStack {
            PhoneBackground()
            VStack(alignment: .leading, spacing: 18) {
                Capsule()
                    .fill(YNXTheme.hairline)
                    .frame(width: 46, height: 5)
                    .frame(maxWidth: .infinity)
                ScreenHeader(
                    eyebrow: "DApp Permission",
                    title: "Connect \(origin)",
                    subtitle: "Grant only the capabilities this Web4 app needs. You can revoke permissions from Wallet."
                )
                GlassCard {
                    VStack(spacing: 12) {
                        Toggle("Read wallet address", isOn: $account)
                        Toggle("Request testnet signatures", isOn: $signatures)
                        Toggle("Encrypted messages", isOn: $encryptedMessages)
                        Toggle("Session keys", isOn: $sessions)
                    }
                    .font(.callout.weight(.semibold))
                }
                Button {
                    var scopes: [String] = []
                    if account { scopes.append("account.read") }
                    if signatures { scopes.append("signature.request.testnet") }
                    if encryptedMessages { scopes.append("message.encrypt") }
                    if sessions { scopes.append("session.issue") }
                    walletStore.grantDAppPermission(origin: origin, scopes: scopes)
                    dismiss()
                } label: {
                    Label("Grant Testnet Permission", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(YNXTheme.klein, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(PressableButtonStyle())
                Spacer()
            }
            .padding(20)
        }
    }
}

struct BrowserWebView: View {
    @ObservedObject var controller: BrowserController

    var body: some View {
        PlatformWebView(controller: controller)
    }
}

#if os(iOS)
struct PlatformWebView: UIViewRepresentable {
    @ObservedObject var controller: BrowserController

    func makeUIView(context: Context) -> WKWebView {
        controller.webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
#else
struct PlatformWebView: NSViewRepresentable {
    @ObservedObject var controller: BrowserController

    func makeNSView(context: Context) -> WKWebView {
        controller.webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}
}
#endif
