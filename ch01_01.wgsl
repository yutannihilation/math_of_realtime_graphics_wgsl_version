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
    
    let RED = vec3(1.0, 0.0, 0.0);
    let BLUE = vec3(0.0, 0.0, 1.0);

    return vec4(mix(RED, BLUE, pos.x), 1.0);
} 