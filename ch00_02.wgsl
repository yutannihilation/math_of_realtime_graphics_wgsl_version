struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
};

struct GlobalsUniform {
    @location(0) resolution: vec2<f32>,
    @location(1) time:       f32,
};

@group(0) @binding(0)
var<uniform> globals: GlobalsUniform;

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let pos = in.pos.xy / globals.resolution;
    return vec4(1.0, pos, 1.0);
}