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
visuals.showFrequencyScaling = false
visuals.primaryPositiveColor = .red
visuals.secondaryPositiveColor = .purple
visuals.tertiaryPositiveColor = .orange
visuals.primaryNegativeColor = nil
visuals.secondaryNegativeColor = nil
visuals.tertiaryNegativeColor = nil
visuals.resolution = 0.4
visuals.opticalDensity = 0.25

let binarySystemViewController = BinarySystemViewController()
binarySystemViewController.visualConfiguration = visuals
page.liveView = binarySystemViewController
