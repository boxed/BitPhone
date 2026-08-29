//
//  Shaders.metal
//  BitPhone
//

#include <metal_stdlib>
using namespace metal;

// Matches Uniforms in Renderer.swift.
struct Uniforms {
    float4x4 modelViewMatrix;
    float4x4 projectionMatrix;
    float3x3 normalMatrix;
    float4 color;
};

// Matches Vertex in BitGeometry.swift.
struct VertexIn {
    float3 position;
    float3 normal;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

// Flat-shaded directional lighting: one light at (0, 0, 1) in eye space and
// an ambient term of 0.3, matching the light the original renderer set up.
vertex VertexOut bit_vertex(uint vertexID [[vertex_id]],
                            device const VertexIn *vertices [[buffer(0)]],
                            constant Uniforms &uniforms [[buffer(1)]])
{
    VertexIn in = vertices[vertexID];
    float3 eyeNormal = normalize(uniforms.normalMatrix * in.normal);
    float light = 0.3 + max(0.0f, eyeNormal.z);

    VertexOut out;
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(in.position, 1.0);
    out.color = float4(uniforms.color.rgb * light, uniforms.color.a);
    return out;
}

fragment float4 bit_fragment(VertexOut in [[stage_in]])
{
    return in.color;
}
