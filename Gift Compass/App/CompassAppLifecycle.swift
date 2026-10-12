import AdjustSdk
import AppTrackingTransparency
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

enum CompassBrowserRotation {
    static var webContentIsVisible = false
}

extension Notification.Name {
    static let compassTokenAvailable = Notification.Name("compassTokenAvailable")
    static let compassNotificationActivated = Notification.Name("compassNotificationActivated")
    static let compassLandingChanged = Notification.Name("compassLandingChanged")
}

enum CompassSessionCache {
    static let serviceLinkKey = "compass.bridge.serviceLink"
    static let responseLinkKey = "compass.bridge.responseLink"
    static let firebaseTokenKey = "compass.bridge.firebaseToken"
    static let firebaseAppIDKey = "compass.bridge.firebaseAppID"
    static let pushIDKey = "compass.bridge.pendingPushID"
    static let pendingPushKey = "compass.bridge.pushPending"
    static let adjustAttributionKey = "compass.bridge.adjustAttribution"
    private static let clientIDKey = "compass.bridge.serverClientID"
    private static let legacyGeneratedClientIDKey = "compass.bridge.clientID"

    static var clientUUID: String {
        ClientIdentity.current
    }

    static var clientID: String? {
        if let saved = UserDefaults.standard.string(forKey: clientIDKey),
           UUID(uuidString: saved) != nil {
            return saved
        }
        return nil
    }

    static func prepareServerClientIdentity() {
        UserDefaults.standard.removeObject(forKey: legacyGeneratedClientIDKey)
    }

    static func storeServerClientID(_ rawValue: String?) {
        guard let value = nonEmpty(rawValue), UUID(uuidString: value) != nil else { return }
        UserDefaults.standard.set(value, forKey: clientIDKey)
    }

    static var firebaseToken: String? {
        nonEmpty(UserDefaults.standard.string(forKey: firebaseTokenKey))
    }

    static var adjustAttributionJSON: String? {
        nonEmpty(UserDefaults.standard.string(forKey: adjustAttributionKey))
    }

    static func consumePushContext() -> (openedFromPush: Bool, pushID: String?) {
        let defaults = UserDefaults.standard
        let openedFromPush = defaults.bool(forKey: pendingPushKey)
        let pushID = openedFromPush ? nonEmpty(defaults.string(forKey: pushIDKey)) : nil
        defaults.removeObject(forKey: pendingPushKey)
        defaults.removeObject(forKey: pushIDKey)
        return (openedFromPush, pushID)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

final class CompassCampaignCollector: NSObject, AdjustDelegate {
    func adjustAttributionChanged(_ attribution: ADJAttribution?) {
        guard let attribution else { return }
        if #available(iOS 14, *),
           ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            return
        }
        guard let jsonResponse = attribution.jsonResponse,
              let data = try? JSONSerialization.data(withJSONObject: jsonResponse, options: []),
              let jsonString = String(data: data, encoding: .utf8) else {
            UserDefaults.standard.removeObject(forKey: CompassSessionCache.adjustAttributionKey)
            return
        }
        UserDefaults.standard.set(jsonString, forKey: CompassSessionCache.adjustAttributionKey)
    }
}

final class GiftCompassAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    private let adjustAppToken = "m9k33ki9t9fk"
    private let attributionCollector = CompassCampaignCollector()

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        CompassBrowserRotation.webContentIsVisible ? .all : .portrait
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = CompassSessionCache.clientUUID
        CompassSessionCache.prepareServerClientIdentity()
        startMessagingPipeline()
        startAttributionPipeline()

        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            stageNotificationOpen(with: userInfo)
        }
        return true
    }

    private func startAttributionPipeline() {
        guard let config = ADJConfig(appToken: adjustAppToken, environment: ADJEnvironmentProduction) else {
            return
        }
        config.delegate = attributionCollector
        config.logLevel = .info
        Adjust.initSdk(config)
    }

    private func startMessagingPipeline() {
        FirebaseApp.configure()
        if let googleAppID = FirebaseApp.app()?.options.googleAppID,
           UserDefaults.standard.string(forKey: CompassSessionCache.firebaseAppIDKey) != googleAppID {
            UserDefaults.standard.removeObject(forKey: CompassSessionCache.firebaseTokenKey)
            UserDefaults.standard.set(googleAppID, forKey: CompassSessionCache.firebaseAppIDKey)
        }
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        Messaging.messaging().isAutoInitEnabled = true
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        retainMessagingToken(fcmToken)
    }

    private func retainMessagingToken(_ rawToken: String?) {
        guard let token = rawToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            return
        }
        UserDefaults.standard.set(token, forKey: CompassSessionCache.firebaseTokenKey)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .compassTokenAvailable, object: nil)
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().token { [weak self] token, error in
            if let error {
                print("FCM token after APNS failed:", error.localizedDescription)
                return
            }
            self?.retainMessagingToken(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNS registration failed:", error.localizedDescription)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Messaging.messaging().appDidReceiveMessage(userInfo)
        stageNotificationOpen(with: userInfo)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .compassNotificationActivated, object: nil)
        }
        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Messaging.messaging().appDidReceiveMessage(userInfo)
        completionHandler(.newData)
    }

    private func stageNotificationOpen(with userInfo: [AnyHashable: Any]) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: CompassSessionCache.pushIDKey)
        if let pushID = notificationIdentifier(from: userInfo) {
            defaults.set(pushID, forKey: CompassSessionCache.pushIDKey)
        }
        defaults.set(true, forKey: CompassSessionCache.pendingPushKey)
    }

    private func notificationIdentifier(from object: Any) -> String? {
        if let dictionary = object as? [AnyHashable: Any] {
            for key in ["push_id", "gcm.notification.push_id"] {
                if let value = dictionary[key] {
                    let text = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty { return text }
                }
            }
            for key in ["push_data", "data"] {
                if let nested = dictionary[key], let value = notificationIdentifier(from: nested) {
                    return value
                }
            }
        } else if let dictionary = object as? [String: Any] {
            let bridged = Dictionary(uniqueKeysWithValues: dictionary.map { (AnyHashable($0.key), $0.value) })
            return notificationIdentifier(from: bridged)
        } else if let text = object as? String,
                  let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) {
            return notificationIdentifier(from: json)
        }
        return nil
    }
}
