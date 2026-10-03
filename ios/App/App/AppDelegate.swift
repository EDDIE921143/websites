import UIKit

@main final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing"){application.isIdleTimerDisabled=true}
        #endif
        let appearance=UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.shadowColor = .clear
        appearance.titleTextAttributes=[.font:UIFontMetrics(forTextStyle:.headline).scaledFont(for:UIFont.systemFont(ofSize:17,weight:.medium)),.foregroundColor:UIColor(white:0.94,alpha:1)]
        appearance.largeTitleTextAttributes=[.font:UIFontMetrics(forTextStyle:.largeTitle).scaledFont(for:UIFont.systemFont(ofSize:30,weight:.medium)),.foregroundColor:UIColor(white:0.94,alpha:1)]
        UINavigationBar.appearance().standardAppearance=appearance
        UINavigationBar.appearance().scrollEdgeAppearance=appearance
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration { UISceneConfiguration(name:"Default Configuration",sessionRole:connectingSceneSession.role) }
}
