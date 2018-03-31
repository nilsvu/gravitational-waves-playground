//
//  LiveView.swift
//
//  Copyright (c) 2017 Nils Leif Fischer. All Rights Reserved.
//

import PlaygroundSupport
import UIKit

let page = PlaygroundPage.current

// Make visual configuration the same as the default in the page
var visuals = VisualConfiguration()
visuals.polarization = .cross
visuals.showFrequencyScaling = true
visuals.primaryPositiveColor = .red
visuals.secondaryPositiveColor = .blue
visuals.tertiaryPositiveColor = nil
visuals.primaryNegativeColor = nil
visuals.secondaryNegativeColor = nil
visuals.tertiaryNegativeColor = nil
visuals.resolution = 0.6
visuals.opticalDensity = 0.2

let binarySystemViewController = BinarySystemViewController()
binarySystemViewController.visualConfiguration = visuals
binarySystemViewController.simulate(BinarySystem(firstMass: 70, secondMass: 60), mergingIn: 5)
page.liveView = binarySystemViewController
