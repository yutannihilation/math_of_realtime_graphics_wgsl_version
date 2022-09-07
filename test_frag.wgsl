struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
};

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    return vec4<f32>(cos(0.04 * in.pos.x), sin(0.001 * in.pos.x) + cos(0.03 * in.pos.y), sin(0.056 * in.pos.y), 1.0);
}