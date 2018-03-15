/*
 BinarySystemViewController.swift
 
 Author: [Nils Leif Fischer](http://nilsleiffischer.de/)
*/

import UIKit
import SceneKit


// MARK: View controller wrapper

public class BinarySystemViewController: UIViewController {
    
    private let simulationView = SCNView(frame: .zero)
    private let simulationScene = SCNScene(named: "CBCScene.scn")
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(simulationView)

        simulationView.allowsCameraControl = true
        simulationView.scene = simulationScene

    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        simulationView.frame = view.bounds
    }
    
}
