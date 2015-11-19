#include <metal_stdlib>

using namespace metal;

constexpr constant float POINT_W = 1;

struct Transform {
    float4x4 transform;
};

struct IsoFactor {
    float isoFactor;
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
    const device IsoFactor& uniforms [[buffer(0)]],
    texture2d<float, access::sample> distanceField [[texture(0)]],
    float4 destination [[color(0)]]) {

    float isoFactor = uniforms.isoFactor;
    
    float2 uv = fragmentIn.uv;
    
    // this is messed up // is it anymore?
    float4 distanceFieldSample = distanceField.sample(simpleSampler, uv);
    float4 offsetDistance = saturate(pow(distanceFieldSample, 1 / isoFactor)); // saturate needed?
    float4 color = 1 - (1 - offsetDistance) * (1 - destination);
    
    FragmentOut fragmentOut;
    fragmentOut.color = color;
    fragmentOut.color.a = 1; //
    
    return fragmentOut;
}