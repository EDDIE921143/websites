import UIKit
import SwiftUI

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene=scene as? UIWindowScene else{return}
        let window=UIWindow(windowScene:scene)
        window.rootViewController=UIHostingController(rootView:NativeRoot())
        window.backgroundColor=UIColor(red:0.035,green:0.04,blue:0.047,alpha:1)
        self.window=window
        window.makeKeyAndVisible()
    }
}
