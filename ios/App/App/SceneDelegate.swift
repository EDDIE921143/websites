import UIKit
import SwiftUI

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var store: NativeStore?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene=scene as? UIWindowScene else{return}
        let window=UIWindow(windowScene:scene)
        let store = NativeStore()
        self.store = store
        window.rootViewController=UIHostingController(rootView:NativeRoot(store:store))
        window.backgroundColor=UIColor(red:0.035,green:0.04,blue:0.047,alpha:1)
        self.window=window
        window.makeKeyAndVisible()
        if let url = connectionOptions.urlContexts.first?.url { store.connectAssistant(url) }
    }
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts { store?.connectAssistant(context.url) }
    }
}
