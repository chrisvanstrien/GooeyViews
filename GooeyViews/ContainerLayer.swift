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
    
    override init() {
        super.init()
        
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        setup()
    }
    
    func setup() {
        
    }
}