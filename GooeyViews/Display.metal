#include <metal_stdlib>

using namespace metal;

constexpr constant float POINT_W = 1;

// Might not even need transform
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
};

vertex VertexOut vertexDisplay(
    const device VertexIn* vertexArray [[buffer(0)]],
    const device Transform& uniforms [[buffer(1)]],
    unsigned int vid [[vertex_id]]) {
    
    float4x4 transform = uniforms.transform;
    
    VertexIn vertexIn = vertexArray[vid];
    float2 uv = vertexIn.uv;
    
    VertexOut vertexOut;
    vertexOut.uv = uv;
    vertexOut.position = transform * float4(vertexIn.position, 0, POINT_W);
    
    return vertexOut;
}

constexpr sampler simpleSampler(filter::linear); // Could even be nearest

fragment FragmentOut fragmentDisplay(
    FragmentIn fragmentIn [[stage_in]],
    texture2d<float, access::sample> filtered [[texture(0)]]) {

    float2 uv = fragmentIn.uv;

    float4 filteredSample = filtered.sample(simpleSampler, uv);
    
    FragmentOut fragmentOut;
    fragmentOut.color = filteredSample;
    
    return fragmentOut;
}