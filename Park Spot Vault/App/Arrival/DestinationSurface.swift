import SwiftUI
@preconcurrency import WebKit

struct DestinationSurface: UIViewControllerRepresentable {
    @Binding var address: URL?

    func makeUIViewController(context: Context) -> DestinationController {
        DestinationController()
    }

    func updateUIViewController(_ controller: DestinationController, context: Context) {
        if let address {
            controller.display(address)
        }
    }
}

final class DestinationController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private var primary: WKWebView!
    private var windows: [WKWebView: UIStackView] = [:]
    private var loading: UIHostingController<ArrivalLoadingPlate>?
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

        let plate = UIHostingController(rootView: ArrivalLoadingPlate())
        addChild(plate)
        view.addSubview(plate.view)
        plate.view.frame = view.bounds
        plate.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        plate.didMove(toParent: self)
        loading = plate
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
        primary.load(URLRequest(url: destination))
    }

    func webView(_ surface: WKWebView, didFinish navigation: WKNavigation!) {
        if surface === primary {
            dismissLoading()
        }
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
        dismissLoading()
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
            surface.load(URLRequest(url: url))
        }
    }

    func webView(_ surface: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        recover(surface, from: error)
    }

    func webView(_ surface: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        recover(surface, from: error)
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

    private func recover(_ surface: WKWebView, from error: Error) {
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
        let delay = Double(networkRetries)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak surface] in
            guard let self, let surface, self.address == currentDestination else { return }
            surface.load(URLRequest(url: retry))
        }
    }

    private func dismissLoading() {
        guard let loading else { return }
        loading.willMove(toParent: nil)
        loading.view.removeFromSuperview()
        loading.removeFromParent()
        self.loading = nil
    }
}

struct ArrivalLoadingPlate: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
                .accessibilityLabel("Loading")
        }
    }
}
