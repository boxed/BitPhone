//
//  SceneDelegate.swift
//  BitPhone
//

import UIKit

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?
    private var viewController: BitViewController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let viewController = BitViewController()
        self.viewController = viewController

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        window.rootViewController = viewController
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        viewController?.setAnimating(true)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        viewController?.setAnimating(false)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        viewController?.setAnimating(false)
    }
}
