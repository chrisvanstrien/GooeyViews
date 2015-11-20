#include <metal_stdlib>

using namespace metal;

constexpr constant float POINT_W = 1;

struct Transform {
    float4x4 transform;
};

struct VertexIn {
    packed_float2 position;
    packed_float2 uv;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv [[user(uv)]];
};

struct FragmentIn {
    float2 uv [[user(uv)]];
};

struct FragmentOut {
    float4 color [[color(0)]];
    float weight [[color(1)]];
    float distance [[color(2)]];
};

vertex VertexOut vertexBlend(
    const device VertexIn* vertexArray [[buffer(0)]],
    const device Transform& uniforms [[buffer(1)]],
    unsigned int vid [[vertex_id]]) {
    
    float4x4 transform = uniforms.transform;
    
    VertexIn vertexIn = vertexArray[vid];
    float2 position = vertexIn.position;
    float2 uv = vertexIn.uv;
    
    VertexOut vertexOut;
    vertexOut.position = transform * float4(position, 0, POINT_W);
    vertexOut.uv = uv;
    vertexOut.uv.y = 1 - vertexOut.uv.y; // flip v cus texture is upsidedown
    
    return vertexOut;
}

constexpr sampler simpleSampler(filter::linear);

fragment FragmentOut fragmentBlend(
    FragmentIn fragmentIn [[stage_in]],
    texture2d<float, access::sample> distanceMap [[texture(0)]],
    texture2d<float, access::sample> colorMap [[texture(1)]],
    float4 accumulatedColor [[color(0)]],
    float accumulatedWeight [[color(1)]],
    float accumulatedDistance [[color(2)]]) {

    float2 uv = fragmentIn.uv;
    
    float distanceSample = distanceMap.sample(simpleSampler, uv).r; // r?
    float4 colorSample = colorMap.sample(simpleSampler, uv);

    float weight = accumulatedWeight + distanceSample;
    
    float mixFactor = clamp(distanceSample / weight, 0.0, 1.0);
    float4 color = mix(accumulatedColor, colorSample, mixFactor);

    // Swap this to multiply when all the buffers are finalized
    float distance = 1 - (1 - distanceSample) * (1 - accumulatedDistance);

    FragmentOut fragmentOut;
    fragmentOut.color = color;
    fragmentOut.weight = weight;
    fragmentOut.distance = distance;

    return fragmentOut;
}