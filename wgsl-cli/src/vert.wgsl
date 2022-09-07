struct VertexInput {
    @location(0) pos: vec2<f32>,
};

struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
};

@vertex
fn vs_main(
   in: VertexInput,
) -> VertexOutput {
    var out: VertexOutput;
    out.pos = vec4(in.pos, 0.0, 1.0);
    return out;
}
