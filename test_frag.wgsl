struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
};

struct GlobalsUniform {
    @location(0) resolution: vec2<f32>,
    @location(1) time: f32,
    @location(2) frame: u32,
    @location(3) mouse_pos: vec2<f32>,
};

@group(0) @binding(0)
var<uniform> globals: GlobalsUniform;

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    return vec4<f32>(in.pos.xy / globals.resolution.xy, sin(globals.time / 10.0), 1.0);
}