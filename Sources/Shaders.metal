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

// Replicates the fixed-function GLES 1.1 lighting the original renderer set
// up: one directional light at (0, 0, 1) in eye space, a combined global +
// light ambient term of 0.3, and the material color tracking glColor. Normals
// are deliberately not renormalized -- some meshes carry unnormalized normals
// (and the modelview scale reaches them through the normal matrix) whose
// lengths modulate the brightness, as in the original.
vertex VertexOut bit_vertex(uint vertexID [[vertex_id]],
                            device const VertexIn *vertices [[buffer(0)]],
                            constant Uniforms &uniforms [[buffer(1)]])
{
    VertexIn in = vertices[vertexID];
    float3 eyeNormal = uniforms.normalMatrix * in.normal;
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
