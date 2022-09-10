struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
};

struct GlobalsUniform {
    @location(0) resolution: vec2<f32>,
    @location(1) time:       f32,
    @location(2) channel:    u32,
};

@group(0) @binding(0)
var<uniform> globals: GlobalsUniform;

let K = vec3<u32>(0x456789abu, 0x6789ab45u, 0x89ab4567u);
let U = vec3<u32>(1u, 2u, 3u);
let UINT_MAX = 0xffffffffu;

//********** Hash functions *********************************************//

fn uhash22(n_in: vec2<u32>) -> vec2<u32> {
    var n = n_in;
    n ^= (n.yx << U.xy);
    n ^= (n.yx >> U.xy);
    n *= K.xy;
    n ^= (n.yx << U.xy);

    return n * K.xy;
}

fn uhash33(n_in: vec3<u32>) -> vec3<u32> {
    var n = n_in;
    n ^= (n.yzx << U);
    n ^= (n.yzx >> U);
    n *= K;
    n ^= (n.yzx << U);

    return n * K;
}

fn hash22(p: vec2<f32>) -> vec2<f32> {
    let n = bitcast<u32>(p);
    return vec2<f32>(uhash22(n)) / vec2(f32(UINT_MAX));
}

fn hash33(p: vec3<f32>) -> vec3<f32> {
    let n = bitcast<u32>(p);
    return vec3<f32>(uhash33(n)) / vec3(f32(UINT_MAX));
}

fn hash21(p: vec2<f32>) -> f32 {
    let n = bitcast<u32>(p);
    return f32(uhash22(n).x) / f32(UINT_MAX);
}

fn hash31(p: vec3<f32>) -> f32 {
    let n = bitcast<u32>(p);
    return f32(uhash33(n).x) / f32(UINT_MAX);
}

//********** Gradient noise *********************************************//

fn gnoise21(p: vec2<f32>) -> f32 {
    let n = floor(p);
    var f = fract(p);

    var diag = array(
        vec2( 0.70710678,  0.70710678),
        vec2(-0.70710678,  0.70710678),
        vec2( 0.70710678, -0.70710678),
        vec2(-0.70710678, -0.70710678)
    );
    var axis = array(
        vec2( 1.,  0.),
        vec2(-1.,  0.),
        vec2( 0.,  1.),
        vec2( 0., -1.)
    );

    var v: array<f32, 4>;
    for (var j = 0; j < 2; j++) {
        for (var i = 0; i < 2; i++) {
            let ij = vec2<f32>(vec2(i, j));

            let m = bitcast<u32>(n + ij);
            let ind = (uhash22(m).x >> 30u);

            if (globals.channel > 0u) {
                v[i+2*j] = dot(diag[ind], f - ij);
            } else {
                v[i+2*j] = dot(axis[ind], f - ij);
            }
        }
    }

    f = f * f * f * (10.0 - 15.0 * f + 6.0 * f * f);
    return 0.5 * mix(mix(v[0], v[1], f[0]), mix(v[2], v[3], f[0]), f[1]) + 0.5;
}

//********** Rotation *********************************************//

fn rot2(p: vec2<f32>, t: f32) -> vec2<f32> {
    return vec2(
        cos(t) * p.x - sin(t) * p.y,
        sin(t) * p.x - cos(t) * p.y
    );
}

fn rotX(p: vec3<f32>, t: f32) -> vec3<f32> {
    let res = rot2(p.yz, t);
    return vec3(1.0, res[0], res[1]);
}

fn rotY(p: vec3<f32>, t: f32) -> vec3<f32> {
    let res = rot2(p.xz, t);
    return vec3(res[0], 1.0, res[1]);
}

fn rotZ(p: vec3<f32>, t: f32) -> vec3<f32> {
    let res = rot2(p.xy, t);
    return vec3(res[0], res[1], 1.0);
}

fn rotNoise21(p: vec2<f32>, ang: f32) -> f32 {
    let n = floor(p);
    var f = fract(p);

    var v: array<f32, 4>;
    for (var j = 0; j < 2; j++) {
        for (var i = 0; i < 2; i++) {
            let ij = vec2<f32>(vec2(i, j));
            var g  = normalize(hash22(n + ij) - 0.5);
            g = rot2(g, ang);
            v[i+2*j] = dot(g, f - ij);
        }
    }

    f = f * f * f * (10.0 - 15.0 * f + 6.0 * f * f);
    return 0.5 * mix(mix(v[0], v[1], f[0]), mix(v[2], v[3], f[0]), f[1]) + 0.5;
}

//********** Utilities *********************************************//

fn hsv2rgb(c: vec3<f32>) -> vec3<f32> {
    // `saturate(e)` is a shortcut of `clamp(e, 0.0, 1.0)`.
    let rgb = saturate(abs((c.x * 6.0 + vec3(0.0, 4.0, 2.0)) % 6.0 - 3.0) - 1.0);

    return c.z * mix(vec3(1.0), rgb, c.y);
}


//********** Main *********************************************//

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    var pos = in.pos.xy / globals.resolution.xy;

    var f: f32;
    f = gnoise21(25.0 * pos + globals.time);
    if (f > 0.85 || f < 0.15) {
        return vec4(1.0, 0.0, 0.0, 1.0);
    } else {
        return vec4(vec3(f), 1.0);
    }

}
