import Metal
import QuartzCore
import MetalKit

class UniformFactory {
    let FLOAT_SIZE = sizeof(Float)
    
    var device: MTLDevice!
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    func matrixUniformBuffer(matrices matrices: [CATransform3D]) -> MTLBuffer {
        let packed = matrices.flatMap { MatrixFactory.array($0) }
        
        let size = packed.count * FLOAT_SIZE
        
        let buffer = device.newBufferWithBytes(packed, length: size, options: [])
        
        return buffer
    }
    
    // Make one that takes an array
    func floatUniformBuffer(value value: Float) -> MTLBuffer {
        let packed = [value]
        
        let size = FLOAT_SIZE
        
        let buffer = device.newBufferWithBytes(packed, length: size, options: [])
        
        return buffer
    }
}