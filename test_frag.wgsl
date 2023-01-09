struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
};

struct GlobalsUniform {
    @location(0) resolution: vec2<f32>,
    @location(1) time: f32,
    // @location(2) frame: u32,
    @location(3) mouse_pos: vec2<f32>,
};

@group(0) @binding(0)
var<uniform> globals: GlobalsUniform;

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    // return vec4(in.pos.xy / globals.resolution.xy * vec2(0.5 + sin(0.42 * globals.time * in.pos.x / 799.) * cos(0.51 * globals.time), sin(0.73 * globals.time * in.pos.y / 777.)), sin(0.98 * globals.time), 1.0);
    return vec4(globals.mouse_pos / globals.resolution, 1.0, 1.0);
}