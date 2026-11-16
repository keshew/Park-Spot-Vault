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
    private var windows: [WKWebView] = []
    private var loading: UIHostingController<ArrivalLoadingPlate>?
    private var address: URL?
    private var networkRetries = 0
    private var processRestarts = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let surface = install(configuration, inset: true)
        primary = surface

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
        let child = install(configuration, inset: false)
        windows.append(child)
        return child
    }

    func webViewDidClose(_ surface: WKWebView) {
        guard surface !== primary else { return }
        surface.removeFromSuperview()
        windows.removeAll { $0 === surface }
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

    private func install(_ configuration: WKWebViewConfiguration, inset: Bool) -> WKWebView {
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let surface = WKWebView(frame: .zero, configuration: configuration)
        surface.customUserAgent = ArrivalDirectory.pageAgent
        surface.navigationDelegate = self
        surface.uiDelegate = self
        surface.allowsBackForwardNavigationGestures = true
        surface.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(surface)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: inset ? safeArea.topAnchor : view.topAnchor),
            surface.leadingAnchor.constraint(equalTo: inset ? safeArea.leadingAnchor : view.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: inset ? safeArea.trailingAnchor : view.trailingAnchor),
            surface.bottomAnchor.constraint(equalTo: inset ? safeArea.bottomAnchor : view.bottomAnchor)
        ])
        return surface
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

private struct ArrivalLoadingPlate: View {
    var body: some View {
        ZStack {
            VaultBackground()
            LoadingScreen()
        }
        .environment(\.colorScheme, .dark)
    }
}
