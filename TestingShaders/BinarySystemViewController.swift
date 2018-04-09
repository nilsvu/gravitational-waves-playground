//
//  BinarySystemViewController.swift
//
//  Created by Nils Fischer on 23.03.18.
//  Copyright © 2018 Nils Leif Fischer. All rights reserved.
//

/*
 Steps to move into PlaygroundBook format:
 
 - Compile in Xcode to generate Metal library.
 - Copy the following assets to <PlaygroundBook>/Contents/PrivateResources/:
    - CBCScene.scn
    - volume_rendering_technique.plist
    - Products/<ProductName>.app/default.metallib
    - volume_rendering.metal (optional)
    - art.scnassets/
    - Assets.xcassets/restart_icon
 
 */

import UIKit
import ARKit
import SceneKit
import MetalKit

/// A system of two black holes that inspirals and merges, emitting gravitational waves
public struct BinarySystem {
    
    public let firstMass: Float
    public let secondMass: Float
    
    public init(firstMass: Float = 35, secondMass: Float = 30) {
        self.firstMass = firstMass
        self.secondMass = secondMass
    }

    public var totalMass: Float { return firstMass + secondMass }
    
    public var chirpMass: Float {
        return pow(firstMass * secondMass, 3 / 5) / pow(totalMass, 1 / 5)
    }

}

/// A polarization state of a gravitational wave.
public enum GravitationalWavePolarization {
    case plus, cross
}

/// A visual configuration of the simulated scene.
public struct VisualConfiguration {
    
    /// The wave polarization to visualize.
    public var polarization: GravitationalWavePolarization = .cross
    
    /// Colors chosen for large positive field values
    public var primaryPositiveColor: UIColor? = .red
    /// Color chosen for intermediate positive field values
    public var secondaryPositiveColor: UIColor? = .blue
    /// Color chosen for small positive field values
    public var tertiaryPositiveColor: UIColor? = nil
    /// Colors chosen for large negative field values
    public var primaryNegativeColor: UIColor? = .green
    /// Color chosen for intermediate negative field values
    public var secondaryNegativeColor: UIColor? = nil
    /// Color chosen for small negative field values
    public var tertiaryNegativeColor: UIColor? = nil

    /// Size of smallest substructure that the volume rendering can resolve. Lowering this value can heavily decrease rendering framerate.
    public var resolution: Float = 0.3
    /// The increase in opacity when looking through one unit of distance. Lower values make the volume rendering appear more transparent.
    public var opticalDensity: Float = 0.3
    
    /// Enable to visualize the physical quantity Psi4 that scales with the frequency squared, instead of the gravitational wave strain
    public var showFrequencyScaling: Bool = false
    
    public init() {}
}

public class BinarySystemViewController: UIViewController, SCNSceneRendererDelegate, ARSCNViewDelegate, ARSessionDelegate {
    
    private var binarySystem = BinarySystem()
    private var timeToMerger: TimeInterval = 15
    
    // MARK: Scales
    
    private let orbitalSeparationScale: Float = 0.1
    private let timeScale: Float = 200
    private let waveTravelSpeedScale: Float = 0.01
    private let objectSizeScale: Float = 1 / 200
    private let ringdownAmplitudeScale: Float = 0.5 // Amplitude of ringdown in world coordinates (order 1)
    private let ringdownTimeScale: Float = 0.5 // Seconds for ringdown amplitude to decay by 1/e
    private let ringdownFrequency: Float = 1.0 // Frequency of ringdown in Hz

    
    // MARK: Scene setup
  
    private lazy var simulationView: SCNView = {
        let view = SCNView(frame: .zero)
        view.rendersContinuously = true
        view.scene = self.scene
//        view.session = self.session
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
//        view.showsStatistics = true
        view.debugOptions = [
//            ARSCNDebugOptions.showFeaturePoints,
//            ARSCNDebugOptions.showWorldOrigin,
//            .showBoundingBoxes,
//            .showWireframe,
//            .showPhysicsShapes,
//            .showCameras
        ]
        view.delegate = self
        return view
    }()
    
    private lazy var scene: SCNScene = {
        let scene = SCNScene(named: "CBCScene.scn")!
        scene.background.contents = [
            "art.scnassets/px.png", "art.scnassets/nx.png", "art.scnassets/py.png", "art.scnassets/ny.png", "art.scnassets/pz.png", "art.scnassets/nz.png"
        ]
        return scene
    }()
    
    
    // MARK: Volume rendering setup
    
    private lazy var volumeRendering: SCNTechnique = {
        let technique = SCNTechnique(dictionary: NSDictionary(contentsOfFile: Bundle.main.path(forResource: "volume_rendering_technique", ofType: "plist")!) as! [String:AnyObject])!
        technique.setValue(Float(self.orbitalSeparationScale), forKey: "orbitalSeparationScale")
        technique.setValue(Float(self.timeScale), forKey: "timeScale")
        technique.setValue(Float(self.waveTravelSpeedScale), forKey: "waveTravelSpeedScale")
        return technique
    }()
    
    
    // MARK: AR Setup
    
    private lazy var session: ARSession = {
        let session = ARSession()
        session.delegate = self
        return session
    }()
    
    private lazy var worldTracking: ARWorldTrackingConfiguration = {
        let worldTracking = ARWorldTrackingConfiguration()
        worldTracking.planeDetection = .horizontal
        return worldTracking
    }()

    
    // MARK: Nodes
    
    private lazy var firstObject: SCNNode = {
        let node = self.scene.rootNode.childNode(withName: "first_object", recursively: true)!
        node.geometry?.shaderModifiers = [ .geometry: self.objectGeometryShaderModifier ]
        node.geometry?.setValue(Float(self.orbitalSeparationScale), forKey: "orbitalSeparationScale")
        node.geometry?.setValue(Float(self.objectSizeScale), forKey: "objectSizeScale")
        node.geometry?.setValue(Float(self.timeScale), forKey: "timeScale")
        return node
   }()
    private lazy var secondObject: SCNNode = {
        let node = self.scene.rootNode.childNode(withName: "second_object", recursively: true)!
        node.geometry?.shaderModifiers = [ .geometry: self.objectGeometryShaderModifier ]
        node.geometry?.setValue(Float(self.orbitalSeparationScale), forKey: "orbitalSeparationScale")
        node.geometry?.setValue(Float(self.objectSizeScale), forKey: "objectSizeScale")
        node.geometry?.setValue(Float(self.timeScale), forKey: "timeScale")
        return node
    }()
    private lazy var remnant: SCNNode = {
        let node = self.scene.rootNode.childNode(withName: "remnant", recursively: true)!
        node.geometry?.shaderModifiers = [ .geometry: self.remnantGeometryShaderModifier ]
        node.geometry?.setValue(Float(self.orbitalSeparationScale), forKey: "orbitalSeparationScale")
        node.geometry?.setValue(Float(self.objectSizeScale), forKey: "objectSizeScale")
        node.geometry?.setValue(Float(self.timeScale), forKey: "timeScale")
        node.geometry?.setValue(Float(self.ringdownAmplitudeScale), forKey: "ringdownAmplitudeScale")
        node.geometry?.setValue(Float(self.ringdownTimeScale), forKey: "ringdownTimeScale")
        node.geometry?.setValue(Float(self.ringdownFrequency), forKey: "ringdownFrequency");
        return node
    }()
    
    private lazy var sourcePosition: SCNVector3 = {
        self.remnant.position
    }()

    
    // MARK: Object geometry shading setup
    
    private let objectGeometryShaderModifier = """
        #pragma arguments
        float chirpMass;
        float initialOrbitalAngle;
        float mergerTime;
        float schwarzschildRadius;
        float orbitalSeparationFraction;

        float orbitalSeparationScale;
        float objectSizeScale;
        float timeScale;

        #pragma body

        float t = (scn_frame.time - mergerTime) * timeScale;
        float f = pow(chirpMass, -5.0 / 8.0) * pow(abs(t), -3.0 / 8.0);//pow(chirpMass, -5.0 / 8.0) * pow(15.0 * 200.0, -3.0 / 8.0);

        float orbitalAngle = step(0.0, -t) * M_PI_F * pow(f * chirpMass, -5.0 / 3.0)/*f * -t*/ + initialOrbitalAngle;
        float orbitalSeparation = orbitalSeparationScale * pow(chirpMass / 4.0, 1.0 / 3.0) * pow(M_PI_F * f, -2.0 / 3.0);
        float3 x = float3(orbitalSeparationFraction * orbitalSeparation, M_PI_2_F, orbitalAngle);
        float3 objectCenter = x.x * float3(cos(x.z) * sin(x.y), cos(x.y), -sin(x.z) * sin(x.y));
        
        float3 objectRadialUnit = _geometry.normal;
        float vertexDistance = objectSizeScale * schwarzschildRadius;
        
        _geometry.position = float4(objectCenter + vertexDistance * objectRadialUnit, 1.0);
        """
    
    private let remnantGeometryShaderModifier = """
        #pragma arguments
        float schwarzschildRadius;
        float chirpMass;
        float initialOrbitalAngle;
        float mergerTime;
        float ringdownFrequency;

        float objectSizeScale;
        float timeScale;
        float ringdownAmplitudeScale;
        float ringdownTimeScale;

        #pragma body
        float t = (scn_frame.time - mergerTime) * timeScale;
        float3 objectRadialUnit = _geometry.normal;
        float theta = atan2(length(objectRadialUnit.xz), objectRadialUnit.y) + M_PI_F;
        float phi = atan2(-objectRadialUnit.z, objectRadialUnit.x) + M_PI_F + initialOrbitalAngle;
        float ringdownAmplitude = ringdownAmplitudeScale * exp(-t / timeScale / ringdownTimeScale);
        float vertexDistance = objectSizeScale * schwarzschildRadius * (1.0 + ringdownAmplitude * (pow(sin(theta) * sin(2 * M_PI_F * ringdownFrequency * t / timeScale + phi), 2.0) - 0.5));
        
        _geometry.position = float4(vertexDistance * objectRadialUnit, 1.0);
        // TODO: also update normal
        """

    
    // MARK: Public interface
    
    /// Simulates a binary system that merges in `timeToMerger` (real-time) seconds from now.
    public func simulate(_ binarySystem: BinarySystem, mergingIn timeToMerger: TimeInterval) {
        self.binarySystem = binarySystem
        self.timeToMerger = timeToMerger
        self.restartSimulation()
    }

    /// Restarts the simulation.
    public func restartSimulation() {
        guard let initialSceneTime = self.initialSceneTime else {
            return
        }
        let mergerTime = (Date.timeIntervalSinceReferenceDate - initialSceneTime) + timeToMerger
        
        // Check for Metal compatibility
        guard simulationView.renderingAPI == .metal else {
            let alert = UIAlertController(title: "Metal incompatible hardware", message: "This app requires a device that is compatible with Apple's Metal GPU processeing framework.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            return
        }
        
        // Configure volume rendering
        volumeRendering.setValue(NSValue(scnVector3: sourcePosition), forKey: "sourcePosition")
        volumeRendering.setValue(Float(mergerTime), forKey: "mergerTime")
        volumeRendering.setValue(Float(binarySystem.chirpMass), forKey: "chirpMass")
        volumeRendering.setValue(Float(2 * binarySystem.firstMass * objectSizeScale), forKey: "firstObjectRadius")
        volumeRendering.setValue(Float(2 * binarySystem.secondMass * objectSizeScale), forKey: "secondObjectRadius")

        // Configure object geometry shading
        firstObject.geometry?.setValue(Float(2 * binarySystem.firstMass), forKey: "schwarzschildRadius");
        firstObject.geometry?.setValue(Float(binarySystem.chirpMass), forKey: "chirpMass");
        firstObject.geometry?.setValue(Float(0), forKey: "initialOrbitalAngle");
        firstObject.geometry?.setValue(Float(binarySystem.secondMass / binarySystem.totalMass), forKey: "orbitalSeparationFraction");
        firstObject.geometry?.setValue(Float(mergerTime), forKey: "mergerTime");
        secondObject.geometry?.setValue(Float(2 * binarySystem.secondMass), forKey: "schwarzschildRadius");
        secondObject.geometry?.setValue(Float(binarySystem.chirpMass), forKey: "chirpMass");
        secondObject.geometry?.setValue(Float.pi, forKey: "initialOrbitalAngle");
        secondObject.geometry?.setValue(Float(binarySystem.firstMass / binarySystem.totalMass), forKey: "orbitalSeparationFraction");
        secondObject.geometry?.setValue(Float(mergerTime), forKey: "mergerTime");
        remnant.geometry?.setValue(Float(2 * binarySystem.totalMass), forKey: "schwarzschildRadius");
        remnant.geometry?.setValue(Float(binarySystem.chirpMass), forKey: "chirpMass");
        remnant.geometry?.setValue(Float(0), forKey: "initialOrbitalAngle");
        remnant.geometry?.setValue(Float(mergerTime), forKey: "mergerTime");
        
        remnant.removeAllActions()
        remnant.opacity = 0
        remnant.runAction(.sequence([ .wait(duration: TimeInterval(timeToMerger - 0.2)), .fadeOpacity(to: 1, duration: 0) ]))
        firstObject.removeAllActions()
        firstObject.opacity = 1
        firstObject.runAction(.sequence([ .wait(duration: TimeInterval(timeToMerger)), .fadeOpacity(to: 0, duration: 0) ]))
        secondObject.removeAllActions()
        secondObject.opacity = 1
        secondObject.runAction(.sequence([ .wait(duration: TimeInterval(timeToMerger)), .fadeOpacity(to: 0, duration: 0) ]))
    }
    
    /// Applies a visual configuration to the scene.
    private func apply(_ visualConfiguration: VisualConfiguration) {
        applyVolumeRenderingColor(visualConfiguration.primaryPositiveColor, forParameter: "primaryPositiveColor", defaultComponents: [ 1, 0, 0, 1 ])
        applyVolumeRenderingColor(visualConfiguration.secondaryPositiveColor, forParameter: "secondaryPositiveColor", defaultComponents: [ 0, 0, 1, 1 ])
        applyVolumeRenderingColor(visualConfiguration.tertiaryPositiveColor, forParameter: "tertiaryPositiveColor", defaultComponents: [ 0, 0, 0, 0 ])
        applyVolumeRenderingColor(visualConfiguration.primaryNegativeColor, forParameter: "primaryNegativeColor", defaultComponents: [ 0, 0, 0, 0 ])
        applyVolumeRenderingColor(visualConfiguration.secondaryNegativeColor, forParameter: "secondaryNegativeColor", defaultComponents: [ 0, 0, 0, 0 ])
        applyVolumeRenderingColor(visualConfiguration.tertiaryNegativeColor, forParameter: "tertiaryNegativeColor", defaultComponents: [ 0, 0, 0, 0 ])
        volumeRendering.setValue(Float(visualConfiguration.resolution), forKey: "rayStride")
        volumeRendering.setValue(Float(visualConfiguration.opticalDensity), forKey: "opticalDensity")
        let hcrossFraction: Float = {
            switch visualConfiguration.polarization {
            case .plus: return 0
            case .cross: return 1
            }
        }()
        volumeRendering.setValue(Float(hcrossFraction), forKey: "hcrossFraction")
        volumeRendering.setValue(visualConfiguration.showFrequencyScaling ? Int(1) : Int(0), forKey: "showFrequencyScaling")
    }
    
    private func applyVolumeRenderingColor(_ color: UIColor?, forParameter parameter: String, defaultComponents: [CGFloat]) {
        var components: [CGFloat] = {
            if let color = color {
                return color.cgColor.components ?? defaultComponents
            } else {
                return [ 0, 0, 0, 0 ]
            }
        }()
        if components.count < 4 {
            components = defaultComponents
        }
        volumeRendering.setValue(NSValue(scnVector4: SCNVector4(components[0], components[1], components[2], components[3])), forKey: parameter)
    }
    
    
    // MARK: Interface elements
    
    private lazy var restartButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "restart_icon"), for: .normal)
        button.addTarget(self, action: #selector(BinarySystemViewController.restartButtonPressed(sender:)), for: .touchUpInside)
        return button
    }()

    
    // MARK: View lifecycle

    public var visualConfiguration: VisualConfiguration? = nil {
        didSet {
            if let visualConfiguration = visualConfiguration {
                self.apply(visualConfiguration)
            } else {
                let visualConfiguration = VisualConfiguration()
                self.visualConfiguration = visualConfiguration
                self.apply(visualConfiguration)
            }
        }
    }
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.view = simulationView
        
        // Add interface elements
        self.view.addSubview(restartButton)
        let margins = view.layoutMarginsGuide
        restartButton.trailingAnchor.constraint(equalTo: margins.trailingAnchor).isActive = true
        restartButton.centerYAnchor.constraint(equalTo: margins.centerYAnchor).isActive = true
        restartButton.isHidden = true
        
        // Apply default visual configuration
        if self.visualConfiguration == nil {
            self.visualConfiguration = VisualConfiguration()
        }
    }
    
    @IBAction func restartButtonPressed(sender: UIButton) {
        restartSimulation()
    }
    
    private var initialSceneTime: TimeInterval?
    override public func viewDidAppear(_ animated: Bool) {
        
        // Check for Metal compatibility
        if simulationView.renderingAPI == .metal {
            
            // Apply volume rendering technique
            simulationView.technique = volumeRendering
            
        }

        // Run AR world tracking
//        session.run(worldTracking, options: [
//            .resetTracking, .removeExistingAnchors
//            ])
        
        // This is the timestamp where the scn_frame.time in the Metal shaders begins
        self.initialSceneTime = Date.timeIntervalSinceReferenceDate
        
        restartSimulation()
    }

    
    // MARK: SCNSceneRendererDelegate
    
    public func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        // Set volume rendering camera field of view
        if let cameraNode = simulationView.pointOfView,
            let camera = cameraNode.camera,
            let volumeRendering = simulationView.technique {
            volumeRendering.setValue(Float(camera.fieldOfView) / 180 * Float.pi, forKey: "fieldOfView")
        }
    }
    
    override public var prefersStatusBarHidden: Bool {
        return true
    }
    
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

}
