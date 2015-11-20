#include <metal_stdlib>

using namespace metal;

constexpr constant float ISOLEVEL_ERROR_MARGIN = 0.0375;

constexpr constant float ISOLEVEL = 1 - ISOLEVEL_ERROR_MARGIN;

constexpr constant float INTERPOLATION_RANGE = 0.0375;

kernel void kernelThreshold(
    texture2d<float, access::read> accumulatedColor [[texture(0)]],
    texture2d<float, access::write> thresholded [[texture(1)]],
    texture2d<float, access::read> accumulatedDistance [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]) {
    
    float4 colorSample = accumulatedColor.read(gid);
    float distanceSample = accumulatedDistance.read(gid).x; // x?
    
    float threshold = smoothstep(
        ISOLEVEL - INTERPOLATION_RANGE,
        ISOLEVEL,
        distanceSample);
    
    float4 final = float4(colorSample.rgb, colorSample.a * threshold); // Just multiplying these is wrong?
    
    thresholded.write(final, gid);
}