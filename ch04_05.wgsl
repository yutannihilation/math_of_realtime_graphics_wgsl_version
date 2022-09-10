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
let PI = 3.1415926;

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

//********** Perlin Noise *********************************************//

fn gtable3(lattice: vec3<f32>, p: vec3<f32>) -> f32 {
    let n = bitcast<u32>(lattice);
    let ind = (uhash33(n).x >> 28u);
    // select()'s argument is `select(<false case>, <true case>, <condition>)`
    let u = select(p.x, p.y, ind >= 8u);
    let v = select(p.y, select(p.z, p.x, ind == 12u || ind == 14u), ind >= 4u);
    return select(-u, u, (ind & 1u) == 0u) + select(-v, v, (ind & 2u) == 0u);
}

fn pnoise31(p: vec3<f32>) -> f32 {
    let n = floor(p);
    var f = fract(p);

    var v: array<f32, 8>;
    for (var k = 0; k < 2; k++) {
        for (var j = 0; j < 2; j++) {
            for (var i = 0; i < 2; i++) {
                let ijk = vec3(f32(i), f32(j), f32(k));
                v[i+2*j+4*k] = gtable3(n + ijk, f - ijk) * 0.70710678;
            }
        }
    }

    // Hermite interpolation
    f = f * f * f * (10.0 - 15.0 * f + 6.0 * f * f);

    var w: array<f32, 2>;
    for (var i = 0; i < 2; i++) {
        w[i] = mix(mix(v[4*i], v[4*i+1], f[0]), mix(v[4*i+2], v[4*i+3], f[0]), f[1]);
    }

    return 0.5 * mix(w[0], w[1], f[2]) + 0.5;
}

// we cannot define a function called mod() because it's a reserved keyword
fn mod_floor(x: vec2<f32>, y: f32) -> vec2<f32> {
    return x - y * floor(x/y);
}

fn gtable2(lattice: vec2<f32>, p: vec2<f32>) -> f32 {
    let n = bitcast<u32>(lattice);
    let ind = uhash22(n).x >> 29u;
    // select()'s argument is `select(<false case>, <true case>, <condition>)`
    let u = 0.92387953 * select(p.x, p.y, ind >= 4u);
    let v = 0.38268343 * select(p.y, p.x, ind >= 4u);
    return select(-u, u, (ind & 1u) == 0u) + select(-v, v, (ind & 2u) == 0u);
}

fn pnoise21(p: vec2<f32>) -> f32 {
    let n = floor(p);
    var f = fract(p);

    var v: array<f32, 4>;
    for (var j = 0; j < 2; j++) {
        for (var i = 0; i < 2; i++) {
            let ij = vec2(f32(i), f32(j));
            v[i+2*j] = gtable2(n + ij, f - ij);
        }
    }

    // Hermite interpolation
    f = f * f * f * (10.0 - 15.0 * f + 6.0 * f * f);

    return 0.5 * mix(mix(v[0], v[1], f[0]), mix(v[2], v[3], f[0]), f[1]) + 0.5;
}


fn perinoise21(p: vec2<f32>, period: f32) -> f32 {
    let n = floor(p);
    var f = fract(p);

    var v: array<f32, 4>;
    for (var j = 0; j < 2; j++) {
        for (var i = 0; i < 2; i++) {
            let ij = vec2(f32(i), f32(j));
            v[i+2*j] = gtable2(mod_floor(n + ij, period), f - ij);
        }
    }

    // Hermite interpolation
    f = f * f * f * (10.0 - 15.0 * f + 6.0 * f * f);

    return 0.5 * mix(mix(v[0], v[1], f[0]), mix(v[2], v[3], f[0]), f[1]) + 0.5;
}

//********** Utilities *********************************************//

fn hsv2rgb(c: vec3<f32>) -> vec3<f32> {
    // `saturate(e)` is a shortcut of `clamp(e, 0.0, 1.0)`.
    let rgb = saturate(abs((c.x * 6.0 + vec3(0.0, 4.0, 2.0)) % 6.0 - 3.0) - 1.0);

    return c.z * mix(vec3(1.0), rgb, c.y);
}

fn xy2pol(xy: vec2<f32>) -> vec2<f32> {
    return vec2(atan2(xy.y, xy.x), length(xy));
}


//********** Main *********************************************//

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    var pos = in.pos.xy / globals.resolution.xy;
    pos = 2.0 * pos - 1.0;
    pos = xy2pol(pos);
    pos = vec2(5.0 / PI, 5.0) * pos + globals.time;

    let f = perinoise21(pos, 10.0);
    return vec4(vec3(f), 1.0);
}
