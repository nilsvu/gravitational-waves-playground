//#-hidden-code
import UIKit
import PlaygroundSupport
let proxy = PlaygroundPage.current.liveView as? PlaygroundRemoteLiveViewProxy
func simulate(_ binarySystem: BinarySystem, mergingIn timeToMerger: TimeInterval) {
    proxy?.send(.dictionary([
        "binarySystem": binarySystem.playgroundValue,
        "timeToMerger": .floatingPoint(Double(timeToMerger))
    ]))
}
func apply(_ visualConfiguration: VisualConfiguration) {
    proxy?.send(.dictionary([
        "visualConfiguration": visualConfiguration.playgroundValue
    ]))
}
//#-end-hidden-code
/*:
 # The merger and ringdown phase
 
 We now take a closer look at the situation during and after the two black holes merge. In this final phase, the gravitational pull of the black holes overcomes even their angular momentum. They plunge towards each other, releasing a burst of energy, merge, and then settle down to a final state.
 
 - callout(Explore): Create a binary system of black holes with large masses and pay attention to what happens during and after their merger. Watch how the final black hole is initially deformed and oscillates, but decays to a steady state through a last emission of gravitational waves. Note that it is indeed a little smaller than the two initial black holes combined, since some of their mass was radiated away as energy.
 */
simulate(BinarySystem(firstMass: 70, secondMass: 60), mergingIn: 5)
/*:
 ## More information
 
 - Numerical simulations of binary black hole systems: [Simulating eXtreme Spacetimes collaboration](https://www.black-holes.org)
 - Detection of gravitational waves: [LIGO collaboration](https://www.ligo.caltech.edu)
 */
