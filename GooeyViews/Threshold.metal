#include <metal_stdlib>

using namespace metal;

kernel void kernelThreshold(
    texture2d<float, access::read> blended [[texture(0)]],
    texture2d<float, access::write> thresholded [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]) {
    
    float4 blendedSample = blended.read(gid);
    
    float interpolation = 0.025;
    
    float isolevel = 0.95;
    
    // if min or max goes out of (0, 1) range, bad stuff happens

    float4 threshold = smoothstep(
        isolevel - interpolation,
        isolevel + interpolation,
        blendedSample);
    
    thresholded.write(threshold, gid);
}