import UIKit
import Metal
import QuartzCore
import MetalKit

// matrices only need to hold 2d transform
// uvs can be infered based on local vertex positions

class ViewController: UIViewController {

    var device: MTLDevice!
    
    var commandQueue: MTLCommandQueue!
    
    var threadGroupSize: MTLSize!
    var threadGroupCount: MTLSize!
    
    var metalLayer: CAMetalLayer!
    
    var attributeBuffer: MTLBuffer!
    var indicesBuffer: MTLBuffer!
    
    var blendPipelineState: MTLRenderPipelineState!
    var displayPipelineState: MTLRenderPipelineState!
    var thresholdPipelineState: MTLComputePipelineState!
    
    var heartTexture: MTLTexture!
    var splatTexture: MTLTexture!
    
    var blendedTexture: MTLTexture!
    var thresholdedTexture: MTLTexture!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        device = MTLCreateSystemDefaultDevice()
        
        commandQueue = device.newCommandQueue()
        
        attributeBuffer = {
            let attributes: [Float] = [
                -1,  1,   0, 1,
                 1,  1,   1, 1,
                 1, -1,   1, 0,
                -1, -1,   0, 0]
            
            let attributeSize = attributes.count * sizeof(Float)
            
            return device.newBufferWithBytes(attributes, length: attributeSize, options: [])
        }()
        
        indicesBuffer = {
            let indices: [UInt16] = [
                0, 1, 3,
                1, 2, 3]
            
            let indicesSize = indices.count * sizeof(UInt16)
            
            return device.newBufferWithBytes(indices, length: indicesSize, options: [])
        }()
        
        let screenPixelSize: CGSize = {
            let screen = UIScreen.mainScreen()
            let screenPointSize = screen.bounds
            let screenScale = screen.scale
            
            return CGSize(width: screenPointSize.width * screenScale, height: screenPointSize.height * screenScale)
        }()
        
        let screenSize = MTLSize(width: Int(screenPixelSize.width), height: Int(screenPixelSize.height), depth: 1)
        
        metalLayer = {
            let layer = CAMetalLayer()
            layer.device = device
            layer.pixelFormat = .BGRA8Unorm
            layer.framebufferOnly = true
            layer.frame = view.layer.bounds
            layer.drawableSize = screenPixelSize
            
            return layer
        }()
        
        view.layer.addSublayer(metalLayer)
        
        do {
            let textureFactory = TextureFactory(device: device)
            
            heartTexture = textureFactory.createTexture(filename: "arrow", render: false, read: true, write: false)
            splatTexture = textureFactory.createTexture(filename: "heart", render: false, read: true, write: false)
            
            blendedTexture = textureFactory.createEmptyFloatTexture(width: screenSize.width, height: screenSize.height, render: true, read: true, write: false)
            thresholdedTexture = textureFactory.createEmptyFloatTexture(width: screenSize.width, height: screenSize.height, render: false, read: true, write: true)
        }
        
        // Shaders -----
        let library = device.newDefaultLibrary()
        
        let fragmentBlend = library!.newFunctionWithName("fragmentBlend")
        let vertexBlend = library!.newFunctionWithName("vertexBlend")
        
        let fragmentDisplay = library!.newFunctionWithName("fragmentDisplay")
        let vertexDisplay = library!.newFunctionWithName("vertexDisplay")
        
        let kernelThreshold = library!.newFunctionWithName("kernelThreshold")
        // -----
        
        try! thresholdPipelineState = device.newComputePipelineStateWithFunction(kernelThreshold!)
        
        blendPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexBlend
            descriptor.fragmentFunction = fragmentBlend
            descriptor.colorAttachments[0].pixelFormat = .RGBA16Float
            
            return try! device.newRenderPipelineStateWithDescriptor(descriptor)
        }()
        
        displayPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexDisplay
            descriptor.fragmentFunction = fragmentDisplay
            descriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
            
            return try! device.newRenderPipelineStateWithDescriptor(descriptor)
        }()
        
        threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
        
        // Are the additionals needed?
        threadGroupCount = {
            let widthAdditional = min(screenSize.width % threadGroupSize.width, 1)
            let widthCount = screenSize.width/threadGroupSize.width + widthAdditional
            
            let heightAdditional = min(screenSize.height % threadGroupSize.height, 1)
            let heightCount = screenSize.height/threadGroupSize.height + heightAdditional
            
            return MTLSize(width: widthCount, height: heightCount, depth: 1)
        }()
        
        do {
            let displayLink = CADisplayLink(target: self, selector: "step")
            displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
        }
    }
    
    func renderView(transform transform: CATransform3D, isoFactor: Float, texture: MTLTexture, first: Bool) {
        
        let command = commandQueue.commandBuffer()
        
        let encoder: MTLRenderCommandEncoder = {
            
            let renderPassDescriptor: MTLRenderPassDescriptor = {
                let clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
                
                let descriptor = MTLRenderPassDescriptor()
                let attachment = descriptor.colorAttachments[0]
                
                attachment.texture = self.blendedTexture
                attachment.loadAction = first ? .Clear : .Load
                attachment.clearColor = clearColor
                
                return descriptor
            }()
            
            let uniformFactory = UniformFactory(device: device)
            
            let transformUniformBuffer = uniformFactory.matrixUniformBuffer(matrices: [transform])
            let isoFactorUniformBuffer = uniformFactory.floatUniformBuffer(value: isoFactor)
            
            let encoder = command.renderCommandEncoderWithDescriptor(renderPassDescriptor)
            encoder.setRenderPipelineState(self.blendPipelineState)
            encoder.setVertexBuffer(self.attributeBuffer, offset: 0, atIndex: 0) // use set buffers
            encoder.setVertexBuffer(transformUniformBuffer, offset: 0, atIndex: 1) // use set buffers
            encoder.setFragmentBuffer(isoFactorUniformBuffer, offset: 0, atIndex: 0)
            encoder.setFragmentTexture(texture, atIndex: 0)
            encoder.setFrontFacingWinding(.Clockwise)
            encoder.setCullMode(.Back)
            
            return encoder
        }()
        
        encoder.drawIndexedPrimitives(.Triangle, indexCount: 6, indexType: MTLIndexType.UInt16, indexBuffer: indicesBuffer, indexBufferOffset: 0)
        
        encoder.endEncoding()
        
        command.commit()
    }
    
    func step() {
    
        let time = NSDate().timeIntervalSince1970
        let speed = time / 1.0
        let second = fmod(speed, 1.0)
        let piFactor = M_PI * 2 * second
        let wave = CGFloat(sin(piFactor))
        
        // Blend -----
        do {
            let scale = CATransform3DMakeScale(0.5, 0.25, 1)
            let translate = CATransform3DMakeTranslation(-0.35 + 0.15 * wave, 0, 0)
            let transform = CATransform3DConcat(scale, translate)
            
            renderView(transform: transform, isoFactor: 1, texture: heartTexture, first: true)
        }
        
        do {
            let scale = CATransform3DMakeScale(0.5, 0.25, 1)
            let translate = CATransform3DMakeTranslation(0.3, 0, 0)
            let transform = CATransform3DConcat(scale, translate)
            
            renderView(transform: transform, isoFactor: (Float(wave) + 1.0) / 2.0, texture: splatTexture, first: false)
        }
        // -----
        
        // Compute -----
        do {
            let command = commandQueue.commandBuffer()
            
            do {
                let encoder = command.computeCommandEncoder()
                encoder.setComputePipelineState(thresholdPipelineState)
                encoder.setTexture(blendedTexture, atIndex: 0)
                encoder.setTexture(thresholdedTexture, atIndex: 1)
                encoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
                
                encoder.endEncoding()
            }
            
            command.commit()
        }
        // -----
        
        // Display -----
        do {
            let drawable = metalLayer.nextDrawable()!

            let command = commandQueue.commandBuffer()
            
            let encoder: MTLRenderCommandEncoder = {
                
                let renderPassDescriptor: MTLRenderPassDescriptor = {
                    let clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
                    
                    let descriptor = MTLRenderPassDescriptor()
                    let attachment = descriptor.colorAttachments[0]
                    
                    attachment.texture = drawable.texture
                    attachment.loadAction = .Clear
                    attachment.clearColor = clearColor
                    
                    return descriptor
                }()
                
                let transformUniformBuffer: MTLBuffer = {
                    let uniformFactory = UniformFactory(device: device)
                    
                    return uniformFactory.matrixUniformBuffer(matrices: [CATransform3DIdentity])
                }()
                
                let encoder = command.renderCommandEncoderWithDescriptor(renderPassDescriptor)
                encoder.setRenderPipelineState(displayPipelineState)
                encoder.setVertexBuffer(attributeBuffer, offset: 0, atIndex: 0)
                encoder.setVertexBuffer(transformUniformBuffer, offset: 0, atIndex: 1)
                encoder.setFragmentTexture(thresholdedTexture, atIndex: 0)
                encoder.setFrontFacingWinding(.Clockwise)
                encoder.setCullMode(.Back)
                
                return encoder
            }()
        
            encoder.drawIndexedPrimitives(.Triangle, indexCount: 6, indexType: MTLIndexType.UInt16, indexBuffer: indicesBuffer, indexBufferOffset: 0)
            
            encoder.endEncoding()
            
            command.presentDrawable(drawable)
            
            command.commit()
        }
        // -----
    }
}

