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
 # The Nobel Prize in Physics 2017

 On September 14th, 2015 we observed for the first time one of the most violent events in our Universe - the **inspiral and merger of two black holes**. These astrophysical objects are so massive that not even light can escape their gravitational pull, which makes them invisible to us and to our telescopes. But their extreme mass also has another effect: According to Albert Einstein’s theory of general relativity, which is still our best theory of gravity today, their movement heavily distorts the surrounding spacetime and produces **ripples that travel through the Universe with the speed of light**.

 - callout(Explore): In this Playground we make these _gravitational waves_ visible. Create a black hole binary system now, run the code and watch the two black holes inspiral and merge.
 */
let blackHoleBinary = BinarySystem(firstMass: 35, secondMass: 30)
simulate(blackHoleBinary, mergingIn: 15)
/*:
 > This simulation requires a device compatible with [Metal](https://developer.apple.com/metal/) to visualize the gravitational waves. If you find the simulation does not run smoothly on your device, find out how to decrease the resolution on the [next page](@next).
 - callout(Explore): The two black holes we observed in September 2015 were about 35 and 30 times more massive than our sun. Try changing the masses in the code above and run the simulation again. How do the gravitational waves change when you increase the total mass of both black holes, or when you make one much more massive than the other?

 - More information: [The first detection of gravitational waves](glossary://first_detection)
 
 [Next, explore the properties of gravitational waves and get creative with their visualization >>](@next)
 
 ## References
 
 - LIGO Scientific Collaboration and Virgo Collaboration (2016), [Observation of Gravitational Waves from a Binary Black Hole Merger](https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.116.061102)
 - LIGO Scientific Collaboration and Virgo Collaboration (2016), [Improved Analysis of GW150914 Using a Fully Spin-Precessing Waveform Model](https://journals.aps.org/prx/abstract/10.1103/PhysRevX.6.041014)
 */
