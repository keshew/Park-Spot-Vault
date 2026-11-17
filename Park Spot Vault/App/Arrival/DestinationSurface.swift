import SwiftUI
@preconcurrency import WebKit

struct DestinationSurface: UIViewControllerRepresentable {
    let address: URL?
    let didLoad: (URL) -> Void

    func makeUIViewController(context: Context) -> DestinationController {
        DestinationController()
    }

    func updateUIViewController(_ controller: DestinationController, context: Context) {
        controller.didLoad = didLoad
        if let address {
            controller.display(address)
        }
    }
}

final class DestinationController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private var primary: WKWebView!
    private var windows: [WKWebView: UIStackView] = [:]
    var didLoad: ((URL) -> Void)?
    private var initialNavigation: WKNavigation?
    private var address: URL?
    private var networkRetries = 0
    private var processRestarts = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        primary = makePage(configuration)
        mount(primary)

    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
    override var shouldAutorotate: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    func display(_ destination: URL) {
        guard destination != address else { return }
        loadViewIfNeeded()
        address = destination
        networkRetries = 0
        initialNavigation = primary.load(URLRequest(url: destination))
    }

    func webView(_ surface: WKWebView, didFinish navigation: WKNavigation!) {
        guard surface === primary, let navigation, navigation === initialNavigation, let address else { return }
        initialNavigation = nil
        didLoad?(address)
    }

    func webView(
        _ surface: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url, opensExternally(url) {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(
        _ surface: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url, opensExternally(url) {
            UIApplication.shared.open(url)
            return nil
        }
        let child = makePage(configuration)
        let toolbar = UIView()
        toolbar.backgroundColor = .secondarySystemBackground
        let close = UIButton(type: .close)
        close.accessibilityLabel = "Close tab"
        close.addAction(UIAction { [weak self, weak child] _ in
            if let child { self?.closeWindow(child) }
        }, for: .touchUpInside)
        toolbar.addSubview(close)
        close.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolbar.heightAnchor.constraint(equalToConstant: 44),
            close.trailingAnchor.constraint(equalTo: toolbar.layoutMarginsGuide.trailingAnchor),
            close.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor)
        ])
        let window = UIStackView(arrangedSubviews: [toolbar, child])
        window.axis = .vertical
        window.backgroundColor = .systemBackground
        mount(window)
        windows[child] = window
        return child
    }

    func webViewDidClose(_ surface: WKWebView) {
        closeWindow(surface)
    }

    func webView(
        _ surface: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(.prompt)
    }

    private func closeWindow(_ surface: WKWebView) {
        guard let window = windows.removeValue(forKey: surface) else { return }
        surface.stopLoading()
        window.removeFromSuperview()
    }

    func webViewWebContentProcessDidTerminate(_ surface: WKWebView) {
        guard processRestarts < 2 else { return }
        processRestarts += 1
        if let url = surface.url ?? (surface === primary ? address : nil) {
            let recovery = surface.load(URLRequest(url: url))
            if surface === primary, initialNavigation != nil { initialNavigation = recovery }
        }
    }

    func webView(_ surface: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        recover(surface, from: error, navigation: navigation)
    }

    func webView(_ surface: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        recover(surface, from: error, navigation: navigation)
    }

    private func makePage(_ configuration: WKWebViewConfiguration) -> WKWebView {
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let surface = WKWebView(frame: .zero, configuration: configuration)
        surface.customUserAgent = ArrivalDirectory.pageAgent
        surface.navigationDelegate = self
        surface.uiDelegate = self
        surface.allowsBackForwardNavigationGestures = true
        return surface
    }

    private func mount(_ surface: UIView) {
        surface.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(surface)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: safeArea.topAnchor),
            surface.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            surface.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
        ])
    }

    private func opensExternally(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return ["tg", "telegram", "mailto", "tel", "sms", "whatsapp", "itms-apps"].contains(scheme)
    }

    private func recover(_ surface: WKWebView, from error: Error, navigation: WKNavigation?) {
        let failure = error as NSError
        guard failure.domain == NSURLErrorDomain, failure.code != NSURLErrorCancelled else { return }

        let failedAddress = (failure.userInfo[NSURLErrorFailingURLErrorKey] as? URL)
            ?? (failure.userInfo[NSURLErrorFailingURLStringErrorKey] as? String).flatMap(URL.init(string:))
        if failure.code == NSURLErrorUnsupportedURL,
           let failedAddress = failedAddress ?? surface.url,
           let scheme = failedAddress.scheme?.lowercased(),
           scheme != "http", scheme != "https" {
            UIApplication.shared.open(failedAddress)
            return
        }

        let transient = [NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
                         NSURLErrorNetworkConnectionLost, NSURLErrorDNSLookupFailed, NSURLErrorNotConnectedToInternet]
        guard surface === primary, transient.contains(failure.code), networkRetries < 2,
              let retry = failedAddress ?? surface.url ?? address else { return }
        networkRetries += 1
        let currentDestination = address
        let isInitial = navigation != nil && navigation === initialNavigation
        let delay = Double(networkRetries)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak surface] in
            guard let self, let surface, self.address == currentDestination else { return }
            let next = surface.load(URLRequest(url: retry))
            if isInitial { self.initialNavigation = next }
        }
    }

}

struct ArrivalLoadingPlate: View {
    var title = "Connecting…"

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.965).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Color(red: 0.26, green: 0.29, blue: 0.32))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.12, green: 0.15, blue: 0.18))
                Text("Please wait a moment.")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.37))
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .accessibilityElement(children: .combine)
        }
    }
}
