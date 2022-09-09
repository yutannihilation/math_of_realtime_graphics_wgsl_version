struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
};

struct GlobalsUniform {
    @location(0) resolution: vec2<f32>,
    @location(1) time:       f32,
};

@group(0) @binding(0)
var<uniform> globals: GlobalsUniform;

let K = 0x456789abu;
let UINT_MAX = 0xffffffffu;

fn uhash11(n_in: u32) -> u32 {
    var n = n_in;

    n ^= (n << 1u);
    n ^= (n >> 1u);
    n *= K;
    n ^= (n << 1u);

    return n * K;
}

fn hash11(p: f32) -> f32 {
    let n = bitcast<u32>(p);
    return f32(uhash11(n)) / f32(UINT_MAX);
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let t = floor(60.0 * globals.time);
    let pos = in.pos.xy + t;

    return vec4(vec3(hash11(pos.x)), 1.0);
}
