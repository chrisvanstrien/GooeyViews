import UIKit
import Metal
import QuartzCore
import MetalKit

// matrices only need to hold 2d transform
// uvs can be infered based on model vertex positions
// gooeyness factor, runtime property, raises texture to a power, scaling back outer glow

// Input Color: 4 Channel, Normalized // Done, but currently ignoring A channel in shaders
// Input Distance: 1 Channel, Normalized // Currently 4 channel, but only making use of R channel
// Accumulated Weight: 1 Channel, Float // Done
// Color: 4 Channel, Normalized // Done, but currently ignoring A channel in shaders
// Distance: 1 Channel, Normalized // Done
// Threshold Target: 4 Channel, Normalized // Done

class ViewController: UIViewController {
    
    var leatherTexture: MTLTexture!
    var concreteTexture: MTLTexture!
    var heartTexture: MTLTexture!
    var arrowTexture: MTLTexture!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.greenColor()
        
        let container = ContainerLayer()
        container.frame = CGRect(x: 0, y: 0, width: 256, height: 256)
        container.setup()
        
        let textureFactory = TextureFactory(device: container.device!)
        
        heartTexture = textureFactory.createTextureFromFile(filename: "heart", render: false, read: true, write: false)
        arrowTexture = textureFactory.createTextureFromFile(filename: "arrow", render: false, read: true, write: false)
        concreteTexture = textureFactory.createTextureFromFile(filename: "concrete", render: false, read: true, write: false)
        leatherTexture = textureFactory.createTextureFromFile(filename: "leather", render: false, read: true, write: false)
        
        let sub = SubLayer();
        sub.frame = CGRect(x: 0, y: 0, width: 128, height: 128)
        sub.distanceTexture = heartTexture
        sub.colorTexture = leatherTexture
        //sub.backgroundColor = UIColor.blueColor().CGColor
        //sub.opacity = 0.5
        container.addSublayer(sub)
        
        let sub2 = SubLayer();
        sub2.frame = CGRect(x: 32, y: 64, width: 128, height: 128)
        sub2.distanceTexture = heartTexture
        sub2.colorTexture = concreteTexture
        //sub2.backgroundColor = UIColor.redColor().CGColor
        //sub2.opacity = 0.5
        container.addSublayer(sub2)
        
        // ffs it says this defaults to false
        container.opaque = false
        
        view.layer.addSublayer(container)
    }
}

