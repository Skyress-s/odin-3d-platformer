struct Vertex
{
    float3 color : COLOR;
}
struct VOut
{
    float4 sv_position : SV_Position;
    Vertex coarseVertex : Vertex;
}

[shader("vertex")]
VOut vertexMain(uint VertexID : SV_VertexID)
{
    float2 positions[3] = {
        float2(0.0, -0.5),
        float2(0.5, 0.5),
        float2(-0.5, 0.5),
    };

    float3 colors[3] = {
        float3(1.0, 0.0, 0.0),
        float3(0.0, 1.0, 0.0),
        float3(0.0, 0.0, 1.0),
    };

    VOut output;
    output.sv_position = float4(positions[VertexID], 0.0, 1.0);
    output.coarseVertex.color = float3(colors[VertexID]);
    return output;
}

[shader("fragment")]
float4 fragmentMain(VOut input) : SV_Target
{
    float4 color = {1.0, 1.0, 1.0, 1.0};
    return color;
}
