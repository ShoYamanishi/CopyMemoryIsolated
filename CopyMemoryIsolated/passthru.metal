#include <metal_stdlib>
using namespace metal;

struct Uniform {
    float3 color;
};

struct VertexIn {
    float4 position [[ attribute( 0 ) ]];
};

struct VertexOut {
    float4 position [[ position ]];
};

vertex VertexOut vert( const VertexIn vertex_in [[ stage_in ]] ) {
    return VertexOut{ .position = vertex_in.position };
}

fragment float4 frag( VertexOut in [[ stage_in ]], constant Uniform& uniform [[ buffer( 0 ) ]] ) {
    return float4( uniform.color.xyz, 1.0 );
}
