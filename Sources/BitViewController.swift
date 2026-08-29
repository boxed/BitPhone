//
//  BitViewController.swift
//  BitPhone
//

import UIKit

final class BitViewController: UIViewController {
    private var bitView: BitView {
        view as! BitView
    }

    override func loadView() {
        view = BitView(frame: UIScreen.main.bounds)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    func setAnimating(_ animating: Bool) {
        bitView.isPaused = !animating
    }
}
