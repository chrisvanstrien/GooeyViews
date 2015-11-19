#include <metal_stdlib>

using namespace metal;

kernel void kernelThreshold(
    texture2d<float, access::read> blended [[texture(0)]],
    texture2d<float, access::write> thresholded [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]) {
    
    float4 blendedSample = blended.read(gid);
    
    float isolevel = 0.5;
    
    float interpolationRange = 0.0375;

    float4 threshold = smoothstep(
        isolevel - interpolationRange,
        isolevel,
        blendedSample);
    
    threshold.a = 1.0; // 
    
    thresholded.write(threshold, gid);
}