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
    float4 weight [[color(1)]];
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
    float4 accumulatedWeight [[color(1)]]) {

    float2 uv = fragmentIn.uv;
    
    float4 distanceFieldSample = distanceField.sample(simpleSampler, uv);
    float4 colorSample = colorMap.sample(simpleSampler, uv);

    float4 distance;
    distance.a = 1 - (1 - distanceFieldSample.r) * (1 - destination.a);
    distance.rgb = colorSample.rgb;
    
    float4 weight = accumulatedWeight + distanceFieldSample;
    
    FragmentOut fragmentOut;
    fragmentOut.distance = distance;
    fragmentOut.weight = weight;
    
    return fragmentOut;
}