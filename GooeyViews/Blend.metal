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
    float4 distance [[color(0)]];
    float weight [[color(1)]];
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
    texture2d<float, access::sample> distanceField [[texture(0)]],
    texture2d<float, access::sample> colorMap [[texture(1)]],
    float4 destination [[color(0)]],
    float accumulatedWeight [[color(1)]]) {

    float2 uv = fragmentIn.uv;
    
    float4 distanceFieldSample = distanceField.sample(simpleSampler, uv);
    float4 colorSample = colorMap.sample(simpleSampler, uv);

    float newAccumulatedWeight = accumulatedWeight + distanceFieldSample.r;
    
    float mixFactor = clamp(distanceFieldSample.r / newAccumulatedWeight, 0.0, 1.0);
    float3 color = mix(destination.rgb, colorSample.rgb, mixFactor);
    
    float4 distance;
    // Swap this to multiply when all the buffers are finalized
    distance.a = 1 - (1 - distanceFieldSample.r) * (1 - destination.a);
    distance.rgb = color;
    
    FragmentOut fragmentOut;
    fragmentOut.distance = distance;
    fragmentOut.weight = newAccumulatedWeight;
    
    return fragmentOut;
}