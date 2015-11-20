import Metal
import QuartzCore
import MetalKit

class TextureFactory {
    var device: MTLDevice!
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    func createUsage(render render: Bool, read: Bool, write: Bool) -> MTLTextureUsage {
        let renderBits = render ? MTLTextureUsage.RenderTarget.rawValue : 0b0
        let readBits = read ? MTLTextureUsage.ShaderRead.rawValue : 0b0
        let writeBits = write ? MTLTextureUsage.ShaderWrite.rawValue : 0b0
        
        let combinedBits = renderBits | readBits | writeBits
        
        let usage = MTLTextureUsage(rawValue: combinedBits)
        
        return usage
    }
    
    func createEmptyFloatTexture(width width: Int, height: Int, render: Bool, read: Bool, write: Bool) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.RGBA16Float, width: width, height: height, mipmapped: false)
        textureDescriptor.usage = createUsage(render: render, read: read, write: write)
        
        let texture = device.newTextureWithDescriptor(textureDescriptor)
        
        return texture
    }
    
    func createEmptySingleChannelFloatTexture(width width: Int, height: Int, render: Bool, read: Bool, write: Bool) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.R16Float, width: width, height: height, mipmapped: false)
        textureDescriptor.usage = createUsage(render: render, read: read, write: write)
        
        let texture = device.newTextureWithDescriptor(textureDescriptor)
        
        return texture
    }
    
    func createEmptyTexture(width width: Int, height: Int, render: Bool, read: Bool, write: Bool) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.RGBA8Unorm, width: width, height: height, mipmapped: false)
        textureDescriptor.usage = createUsage(render: render, read: read, write: write)
        
        let texture = device.newTextureWithDescriptor(textureDescriptor)
        
        return texture
    }
    
    func createTexture(filename filename: String, render: Bool, read: Bool, write: Bool) -> MTLTexture {
        let loader = MTKTextureLoader(device: device)
        
        let usage = createUsage(render: render, read: read, write: write)
        let options = [MTKTextureLoaderOptionTextureUsage: usage.rawValue]
        
        let url = NSBundle.mainBundle().URLForResource(filename, withExtension: "png")
        let texture = try! loader.newTextureWithContentsOfURL(url!, options: options)
        
        return texture
    }
    
    func createCubeMap(filenames filenames: [String], read: Bool, write: Bool) -> MTLTexture { // [+X, -X, +Y, -Y, +Z, -Z]
        let bytesPerPixel = 4
        let bitsPerComponent = 8
        let width = 512
        let height = 512
        let rowBytes = width * bytesPerPixel
        let imageBytes = rowBytes * height
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let region = MTLRegionMake2D(0, 0, width, height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let textureDescriptor = MTLTextureDescriptor.textureCubeDescriptorWithPixelFormat(MTLPixelFormat.RGBA8Unorm, size: 512, mipmapped: false)
        textureDescriptor.usage = createUsage(render: false, read: read, write: write)
        
        let texture = device.newTextureWithDescriptor(textureDescriptor)
        
        for index in 0...5 {
            let filename = filenames[index]
            let path = NSBundle.mainBundle().pathForResource(filename, ofType: "png")!
            let image = UIImage(contentsOfFile: path)!.CGImage
            
            let context = CGBitmapContextCreate(nil, width, height, bitsPerComponent, rowBytes, colorSpace, CGBitmapInfo(rawValue: CGImageAlphaInfo.NoneSkipLast.rawValue).rawValue)
            CGContextClearRect(context, bounds)
            CGContextDrawImage(context, bounds, image)
            
            let pixelsData = CGBitmapContextGetData(context)
            
            texture.replaceRegion(
                region,
                mipmapLevel: 0,
                slice: index,
                withBytes: pixelsData,
                bytesPerRow: rowBytes,
                bytesPerImage: imageBytes)
        }
        
        return texture
    }
}