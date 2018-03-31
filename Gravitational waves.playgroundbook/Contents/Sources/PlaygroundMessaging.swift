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
import PlaygroundSupport

extension BinarySystemViewController: PlaygroundLiveViewMessageHandler {
    
    public func receive(_ message: PlaygroundValue) {
        switch message {
        case .dictionary(let messageDictionary):
            if let visualConfigRepresentation = messageDictionary["visualConfiguration"],
                let visualConfiguration = VisualConfiguration(visualConfigRepresentation) {
                    self.visualConfiguration = visualConfiguration
            }
            if let binarySystemRepresentation = messageDictionary["binarySystem"],
                let binarySystem = BinarySystem(binarySystemRepresentation),
                let timeToMergerRepresentation = messageDictionary["timeToMerger"],
                case .floatingPoint(let timeToMerger) = timeToMergerRepresentation {
                    self.simulate(binarySystem, mergingIn: TimeInterval(timeToMerger))
            }
        default: return
        }
    }
    
}

extension BinarySystem {
    
    public var playgroundValue: PlaygroundValue {
        return .dictionary([
            "firstMass": .floatingPoint(Double(firstMass)),
            "secondMass": .floatingPoint(Double(secondMass))
        ])
    }
    
    public init?(_ representation: PlaygroundValue) {
        guard case .dictionary(let attributes) = representation else { return nil }
        guard let firstMassRepresentation = attributes["firstMass"],
            case .floatingPoint(let firstMass) = firstMassRepresentation else { return nil }
        guard let secondMassRepresentation = attributes["secondMass"],
            case .floatingPoint(let secondMass) = secondMassRepresentation else { return nil }
        self.init(firstMass: Float(firstMass), secondMass: Float(secondMass))
    }
    
}

// Needed to workaround an apparent compiler bug with the code
// "primaryPositiveColor": primaryPositiveColor?.playgroundValue ?? .array([])
// in the dictionary literal below.
private func representation(for color: UIColor?) -> PlaygroundValue{
    if let color = color {
        return color.playgroundValue
    } else {
        return PlaygroundValue.array([])
    }
}

extension VisualConfiguration {
    
    public var playgroundValue: PlaygroundValue {
        return .dictionary([
            "polarizationIsPlus": .boolean(polarization == .plus),
            "resolution": .floatingPoint(Double(resolution)),
            "opticalDensity": .floatingPoint(Double(opticalDensity)),
            "showFrequencyScaling": .boolean(showFrequencyScaling),
            "primaryPositiveColor": representation(for: primaryPositiveColor),
            "secondaryPositiveColor": representation(for: secondaryPositiveColor),
            "tertiaryPositiveColor": representation(for: tertiaryPositiveColor),
            "primaryNegativeColor": representation(for: primaryNegativeColor),
            "secondaryNegativeColor": representation(for: secondaryNegativeColor),
            "tertiaryNegativeColor": representation(for: tertiaryNegativeColor),
            ])
    }
    
    public init?(_ representation: PlaygroundValue) {
        guard case .dictionary(let attributes) = representation else { return nil }
        self.init()
        if let polarizationIsPlusRepresentation = attributes["polarizationIsPlus"] {
            guard case .boolean(let polarizationIsPlus) = polarizationIsPlusRepresentation else { return nil }
            self.polarization = polarizationIsPlus ? .plus : .cross
        }
        if let resolutionRepresentation = attributes["resolution"] {
            guard case .floatingPoint(let resolution) = resolutionRepresentation else { return nil }
            self.resolution = Float(resolution)
        }
        if let opticalDensityRepresentation = attributes["opticalDensity"] {
            guard case .floatingPoint(let opticalDensity) = opticalDensityRepresentation else { return nil }
            self.opticalDensity = Float(opticalDensity)
        }
        if let showFrequencyScalingRepresentation = attributes["showFrequencyScaling"] {
            guard case .boolean(let showFrequencyScaling) = showFrequencyScalingRepresentation else { return nil }
            self.showFrequencyScaling = showFrequencyScaling
        }
        if let colorRepresentation = attributes["primaryPositiveColor"] {
            self.primaryPositiveColor = UIColor(colorRepresentation)
        }
        if let colorRepresentation = attributes["secondaryPositiveColor"] {
            self.secondaryPositiveColor = UIColor(colorRepresentation)
        }
        if let colorRepresentation = attributes["tertiaryPositiveColor"] {
            self.tertiaryPositiveColor = UIColor(colorRepresentation)
        }
        if let colorRepresentation = attributes["primaryNegativeColor"] {
            self.primaryNegativeColor = UIColor(colorRepresentation)
        }
        if let colorRepresentation = attributes["secondaryNegativeColor"] {
            self.secondaryNegativeColor = UIColor(colorRepresentation)
        }
        if let colorRepresentation = attributes["tertiaryNegativeColor"] {
            self.tertiaryNegativeColor = UIColor(colorRepresentation)
        }
    }
    
}

extension UIColor {

    public var playgroundValue: PlaygroundValue {
        guard let components = cgColor.components else { return .array([]) }
        return .array(components.map({ .floatingPoint(Double($0)) }))
    }
    
    public convenience init?(_ representation: PlaygroundValue) {
        guard case .array(let componentRepresentations) = representation,
            componentRepresentations.count == 4 else { return nil}
        let components: [CGFloat] = componentRepresentations.flatMap({
            if case .floatingPoint(let component) = $0 {
                return CGFloat(component)
            } else {
                return nil
            }
        })
        guard components.count == 4 else { return nil }
        self.init(red: components[0], green: components[1], blue: components[2], alpha: components[3])
    }

}
