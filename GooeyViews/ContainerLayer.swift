import Metal
import QuartzCore
import MetalKit

class ContainerLayer: CAMetalLayer {
    
    var commandQueue: MTLCommandQueue!
    
    var threadGroupSize: MTLSize!
    var threadGroupCount: MTLSize!
    
    var attributeBuffer: MTLBuffer!
    var indicesBuffer: MTLBuffer!
    
    var blendPipelineState: MTLRenderPipelineState!
    var displayPipelineState: MTLRenderPipelineState!
    var thresholdPipelineState: MTLComputePipelineState!
    
    var accumulatedWeightTexture: MTLTexture!
    var accumulatedColorTexture: MTLTexture!
    var accumulatedDistanceTexture: MTLTexture!
    
    var thresholdedTexture: MTLTexture!
    
    // On resize, resize the texture
    // setNeedsDisplay
    // needsDisplayOnBoundsChange
    // Check for divisions by zero
    // take transform and anchor point into account
    // change view transform to map from CA space to MTL space
    // change quad vertices to have top left origin
        
    override init() {
        super.init()
        
        //setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        //setup()
    }
    
    func setup() {
        
        commandQueue = device!.newCommandQueue()
        
        attributeBuffer = {
            let attributes: [Float] = [
                -1,  1,   0, 1,
                 1,  1,   1, 1,
                 1, -1,   1, 0,
                -1, -1,   0, 0]
            
            let attributeSize = attributes.count * sizeof(Float)
            
            return device!.newBufferWithBytes(attributes, length: attributeSize, options: [])
        
        }()
        
        indicesBuffer = {
            let indices: [UInt16] = [
                0, 1, 3,
                1, 2, 3]
            
            let indicesSize = indices.count * sizeof(UInt16)
            
            return device!.newBufferWithBytes(indices, length: indicesSize, options: [])
        }()
        
        let layerPixelSize: CGSize = {
            let screen = UIScreen.mainScreen()
            let screenScale = screen.scale
            
            return CGSize(width: bounds.width * screenScale, height: bounds.height * screenScale)
        }()
        
        let layerSize = MTLSize(width: Int(layerPixelSize.width), height: Int(layerPixelSize.height), depth: 1)
        
        drawableSize = layerPixelSize
        
        do {
            let textureFactory = TextureFactory(device: device!)
            
            accumulatedWeightTexture = textureFactory.createEmptyTexture(width: layerSize.width, height: layerSize.height, format: .R16Float, render: true, read: true, write: false)
            accumulatedColorTexture = textureFactory.createEmptyTexture(width: layerSize.width, height: layerSize.height, format: .RGBA8Unorm, render: true, read: true, write: false)
            accumulatedDistanceTexture = textureFactory.createEmptyTexture(width: layerSize.width, height: layerSize.height, format: .R8Unorm, render: true, read: true, write: false)
            
            thresholdedTexture = textureFactory.createEmptyTexture(width: layerSize.width, height: layerSize.height, format: .RGBA8Unorm, render: false, read: true, write: true)
        }
        
        // Shaders -----
        let library = device!.newDefaultLibrary()
        
        let fragmentBlend = library!.newFunctionWithName("fragmentBlend") // Have defines for all kernel handles.
        let vertexBlend = library!.newFunctionWithName("vertexBlend") //
        
        let fragmentDisplay = library!.newFunctionWithName("fragmentDisplay") //
        let vertexDisplay = library!.newFunctionWithName("vertexDisplay") //
        
        let kernelThreshold = library!.newFunctionWithName("kernelThreshold") //
        // -----
        
        try! thresholdPipelineState = device!.newComputePipelineStateWithFunction(kernelThreshold!)
        
        blendPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexBlend
            descriptor.fragmentFunction = fragmentBlend
            descriptor.colorAttachments[0].pixelFormat = .RGBA8Unorm
            descriptor.colorAttachments[1].pixelFormat = .R16Float
            descriptor.colorAttachments[2].pixelFormat = .R8Unorm
            
            return try! device!.newRenderPipelineStateWithDescriptor(descriptor)
        }()
        
        displayPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexDisplay
            descriptor.fragmentFunction = fragmentDisplay
            
            let attachment = descriptor.colorAttachments[0]
            attachment.pixelFormat = .BGRA8Unorm
            
            // Do blending in shader, unless this is faster?
            attachment.blendingEnabled = true
            attachment.rgbBlendOperation = .Add
            attachment.alphaBlendOperation = .Add
            attachment.sourceRGBBlendFactor = .SourceAlpha
            attachment.sourceAlphaBlendFactor = .SourceAlpha
            attachment.destinationRGBBlendFactor = .OneMinusSourceAlpha
            attachment.destinationAlphaBlendFactor = .OneMinusSourceAlpha
            
            return try! device!.newRenderPipelineStateWithDescriptor(descriptor)
        }()
        
        threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
        
        // Are the additionals needed?
        threadGroupCount = {
            let widthAdditional = min(layerSize.width % threadGroupSize.width, 1)
            let widthCount = layerSize.width/threadGroupSize.width + widthAdditional
            
            let heightAdditional = min(layerSize.height % threadGroupSize.height, 1)
            let heightCount = layerSize.height/threadGroupSize.height + heightAdditional
            
            return MTLSize(width: widthCount, height: heightCount, depth: 1)
            }()
        
        do {
            let displayLink = CADisplayLink(target: self, selector: "step")
            displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
        }
    }
    
    func renderView(transform transform: CATransform3D, distanceMap: MTLTexture, colorMap: MTLTexture, first: Bool) {
        
        let command = commandQueue.commandBuffer()
        
        let encoder: MTLRenderCommandEncoder = {
            
            let renderPassDescriptor: MTLRenderPassDescriptor = {
                let clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
                
                let descriptor = MTLRenderPassDescriptor()
                
                let color = descriptor.colorAttachments[0]
                color.texture = self.accumulatedColorTexture
                color.loadAction = first ? .Clear : .Load
                color.clearColor = clearColor
                
                let weight = descriptor.colorAttachments[1]
                weight.texture = self.accumulatedWeightTexture
                weight.loadAction = first ? .Clear : .Load
                weight.clearColor = clearColor
                
                let distance = descriptor.colorAttachments[2]
                distance.texture = self.accumulatedDistanceTexture
                distance.loadAction = first ? .Clear : .Load
                distance.clearColor = clearColor
                
                return descriptor
            }()
            
            let uniformFactory = UniformFactory(device: device!)
            
            let transformUniformBuffer = uniformFactory.matrixUniformBuffer(matrices: [transform])
            
            let encoder = command.renderCommandEncoderWithDescriptor(renderPassDescriptor)
            encoder.setRenderPipelineState(self.blendPipelineState)
            encoder.setVertexBuffer(self.attributeBuffer, offset: 0, atIndex: 0) // use set buffers
            encoder.setVertexBuffer(transformUniformBuffer, offset: 0, atIndex: 1) // use set buffers
            encoder.setFragmentTexture(distanceMap, atIndex: 0)
            encoder.setFragmentTexture(colorMap, atIndex: 1)
            encoder.setFrontFacingWinding(.Clockwise)
            encoder.setCullMode(.Back)
            
            return encoder
        }()
        
        encoder.drawIndexedPrimitives(.Triangle, indexCount: 6, indexType: MTLIndexType.UInt16, indexBuffer: indicesBuffer, indexBufferOffset: 0)
        
        encoder.endEncoding()
        
        command.commit()
    }
    
    func step() {
        
        // Blend -----
    
        // do first better
        var first = true
        
        for subLayer in sublayers! {
            
            // use get position in view to support nested views
            // take transforms into consideration
            // do this by passing transforms to shaders
            
            if let gooeySubLayer = subLayer as? SubLayer {
                let width = CGRectGetWidth(subLayer.bounds) / CGRectGetWidth(bounds)
                let height = CGRectGetHeight(subLayer.bounds) / CGRectGetHeight(bounds)
                            
                let x: CGFloat = -1.0 + width + CGRectGetMinX(subLayer.frame)/CGRectGetWidth(bounds)*2
                let y: CGFloat = -1.0 + height + CGRectGetMinY(subLayer.frame)/CGRectGetHeight(bounds)*2
                
                let scale = CATransform3DMakeScale(width, height, 1)
                let translate = CATransform3DMakeTranslation(x, y, 0)
                let transform = CATransform3DConcat(scale, translate)

                renderView(transform: transform, distanceMap: gooeySubLayer.distanceTexture, colorMap: gooeySubLayer.colorTexture, first: first)
                
                first = false
            }
        }
        // -----
        
        // Compute -----
        do {
            let command = commandQueue.commandBuffer()
            
            do {
                let encoder = command.computeCommandEncoder()
                encoder.setComputePipelineState(thresholdPipelineState)
                encoder.setTexture(accumulatedColorTexture, atIndex: 0)
                encoder.setTexture(thresholdedTexture, atIndex: 1)
                encoder.setTexture(accumulatedDistanceTexture, atIndex: 2)
                encoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
                
                encoder.endEncoding()
            }
            
            command.commit()
        }
        // -----
        
        // Display -----
        do {
            let drawable = nextDrawable()!
            
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
                    let uniformFactory = UniformFactory(device: device!)
                    
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