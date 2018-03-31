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
 # Gravitational waves made visible
 
 We cannot see gravitational waves, since they are perturbations in the gravitational field around us and have no significant effect on the sensors in our eyes. So to make them visible, this simulation colors the space around the black holes according to the value of the gravitational field. We can modify how the coloring is performed to inspect the physical properties of this elusive radiation.

 - callout(Explore): Gravitational waves come in two **polarizations** that physicists call _cross_ and _plus_. Try to change the polarization from `.cross` to `.plus` and back. Do you see how they have a different pattern, but the same speed, frequency and amplitude?
 */
var visuals = VisualConfiguration()
visuals.polarization = .cross
/*:
 - callout(Explore): A better measure of the **energy** radiated away by a gravitational wave is its second derivative, which increases in amplitude with the square of its frequency. Try enabling this behaviour and watch how the binary system emits a burst of energy when it merges:
 */
visuals.showFrequencyScaling = false
/*:
 You can also adjust the remaining visual parameters of the simulation to inspect the propagation pattern of the gravitational radiation in more detail, or just get creative and produce a visually pleasing scene. Skip to the [next page](@next) when you are done.
 
 - callout(Explore): You can choose **six colors** for the visualization: The primary, secondary and tertiary color for both positive and negative field values. Try setting them to different colors and opacities, or `nil`:
 */
visuals.primaryPositiveColor = .red
visuals.secondaryPositiveColor = .blue
visuals.tertiaryPositiveColor = .orange
visuals.primaryNegativeColor = nil
visuals.secondaryNegativeColor = nil
visuals.tertiaryNegativeColor = nil
/*:
 - callout(Explore): Try adjusting the **resolution** and **optical density** of the visualization. Be aware that smaller resolution values mean that the rendering can resolve smaller structures, but that this may heavily decrease the framerate:
 */
visuals.resolution = 0.4
visuals.opticalDensity = 0.25
/*:
 > Use the rewind button in the simulation view to watch the binary system merge again. You can update the visual configuration anytime during a simulation, so to prevent a reset every time you run the code, remove the following first line:
 */
simulate(BinarySystem(firstMass: 35, secondMass: 30), mergingIn: 15)
apply(visuals)
/*:
 [Next, take a closer look at the final phase of the merger >>](@next)
 */
