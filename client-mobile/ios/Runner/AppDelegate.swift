import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var blurEffectView: UIVisualEffectView?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Privacy Protection: Obscure screen when app goes to background switcher (prevents iOS cache snapshots)
    override func applicationWillResignActive(_ application: UIApplication) {
        let blurEffect = UIBlurEffect(style: .dark)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        if let window = self.window {
            blurEffectView?.frame = window.bounds
            blurEffectView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            if let blurView = blurEffectView {
                window.addSubview(blurView)
            }
        }
    }

    override func applicationDidBecomeActive(_ application: UIApplication) {
        blurEffectView?.removeFromSuperview()
        blurEffectView = null
    }
}
