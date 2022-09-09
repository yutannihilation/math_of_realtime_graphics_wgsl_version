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

//********** Value noise *********************************************//

fn vnoise21(p: vec2<f32>) -> f32 {
    let n = floor(p);
    var v: vec4<f32>;

    for (var j = 0; j < 2; j++) {
        for (var i = 0; i < 2; i++) {
            v[i+2*j] = hash21(n + vec2<f32>(vec2(i, j)));
        }
    }

    var f = fract(p);

    if (globals.channel > 0u) {
        f = f * f * (3.0 - 2.0 * f);
    }

    return mix(mix(v[0], v[1], f[0]), mix(v[2], v[3], f[0]), f[1]);
}

fn vnoise31(p: vec3<f32>) -> f32 {
    let n = floor(p);
    
    var v: array<f32, 8>;
    for (var k = 0; k < 2; k++) {
        for (var j = 0; j < 2; j++) {
            for (var i = 0; i < 2; i++) {
                v[i + 2 * j + 4 * k] = hash31(n + vec3<f32>(vec3(i, j, k)));
            }
        }
    }

    var f = fract(p);

    // Hermite interpolation
    f = f * f * (3.0 - 2.0 * f);

    var w: array<f32, 2>;
    for (var i = 0; i < 2; i++) {
        w[i] = mix(mix(v[4*i], v[4*i+1], f[0]), mix(v[4*i+2], v[4*i+3], f[0]), f[1]);
    }

    return mix(w[0], w[1], f[2]);
}

//********** Gradient *********************************************//

fn grad(p: vec2<f32>) -> vec2<f32> {
    let eps = 0.001;
    return 0.5 * vec2(
        vnoise21(p + vec2(eps, 0.0)) - vnoise21(p - vec2(eps, 0.0)),
        vnoise21(p + vec2(0.0, eps)) - vnoise21(p - vec2(0.0, eps))
    ) / eps;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    var pos = in.pos.xy / globals.resolution.xy;

    let g1 = dot(vec2(1.0), grad(vec2(4.0 + 0.22 * sin(0.33 * globals.time),       4.0 + 0.2  * cos(0.33 * globals.time)      ) * pos + 0.3 * globals.time));
    let g2 = dot(vec2(1.0), grad(vec2(4.0 + 0.2  * sin(0.33 * globals.time + 0.1), 4.0 + 0.23 * cos(0.33 * globals.time + 0.1)) * pos + 0.3 * globals.time));
    return vec4(g1, g2, max(g1, g2), 1.0);
}
