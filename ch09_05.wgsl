struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
};

struct GlobalsUniform {
    @location(0) resolution: vec2<f32>,
    @location(1) time:       f32,
    @location(2) channel:    u32,
    @location(3) mouse:      vec2<f32>,
};

@group(0) @binding(0)
var<uniform> globals: GlobalsUniform;

let K = vec3<u32>(0x456789abu, 0x6789ab45u, 0x89ab4567u);
let U = vec3<u32>(1u, 2u, 3u);
let UINT_MAX = 0xffffffffu;
let PI = 3.1415926;

let SPEED = 0.6;

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

//********** Rotation *********************************************//

fn rot2(p: vec2<f32>, t: f32) -> vec2<f32> {
    return vec2(
        cos(t) * p.x - sin(t) * p.y,
        sin(t) * p.x + cos(t) * p.y
    );
}

fn rotX(p: vec3<f32>, t: f32) -> vec3<f32> {
    let res = rot2(p.yz, t);
    return vec3(p.x, res[0], res[1]);
}

fn rotY(p: vec3<f32>, t: f32) -> vec3<f32> {
    let res = rot2(p.xz, t);
    return vec3(res[0], p.y, res[1]);
}

fn rotZ(p: vec3<f32>, t: f32) -> vec3<f32> {
    let res = rot2(p.xy, t);
    return vec3(res[0], res[1], p.z);
}

fn euler(p: vec3<f32>, t: vec3<f32>) -> vec3<f32> {
    return rotZ(rotY(rotX(p, t.x), t.y), t.z);
}

fn mod2(x: f32, y: f32) -> f32 {
    return x - y * floor(x / y);
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

//********** fBM *********************************************//

fn fbm21(p: vec2<f32>, g: f32) -> f32 {
    var val = 0.0;
    var amp = 1.0;
    var freq = 1.0;

    for (var i = 1; i < 4; i++) {
        val += amp * (pnoise21(freq * p) - 0.5);
        amp *= g;
        freq *= 2.01;
    }

    return 0.5 * val + 0.5;
}

fn warp21(p: vec2<f32>, g: f32) -> f32 {
    var val = 0.0;
    for (var i = 0; i < 4; i++) {
        val = fbm21(p + g * vec2(cos(2.0 * PI * val), sin(2.0 * PI * val)), 0.5);
    }
    return val;
}

//********** Texture *********************************************//

fn tex(st: vec2<f32>, g: f32) -> f32 {
    return warp21(st, g);
}

//********** Utilities *********************************************//

fn hsv2rgb(c: vec3<f32>) -> vec3<f32> {
    // `saturate(e)` is a shortcut of `clamp(e, 0.0, 1.0)`.
    let rgb = saturate(abs((c.x * 6.0 + vec3(0.0, 4.0, 2.0)) % 6.0 - 3.0) - 1.0);

    return c.z * mix(vec3(1.0), rgb, c.y);
}


//********** SDF *********************************************//

// c.f. https://www.shadertoy.com/view/wsSGDG
fn octahedron_sdf_(p_in: vec3<f32>, s: f32) -> f32 {
    let p = abs(p_in);
    let m = p.x + p.y + p.z - s;
    let r = 3.0 * p - m;

    var q: vec3<f32>;
    if r.x < 0.0 {
        q = p.xyz;
    } else if r.y < 0.0 {
        q = p.yzx;
    } else if r.z < 0.0 {
        q = p.zxy;
    } else {
        return m * 0.57735027;
    }

    let k = clamp(0.5 * (q.z - q.y + s), 0.0, s);
    return length(vec3(q.x, q.y - s + k, q.z - k));
}

fn plane_sdf(p: vec3<f32>, n: vec3<f32>, s: f32) -> f32 {
    // sqrt(3) / 2
    return dot(normalize(n), p) - s * 0.86602540378;
}

fn octahedron_sdf(p: vec3<f32>, s: f32) -> f32 {
    let p_abs = abs(p);
    if p_abs.x > 0.001 {
        return (p_abs.x + p_abs.y + p_abs.z - s) * 0.57735027;
    } else if p_abs.y > 0.001 {
        return (p_abs.x + p_abs.y + p_abs.z - s) * 0.57735027;
    } else if abs(p.z) < 0.001 {
        return (p_abs.x + p_abs.y + p_abs.z - s) * 0.57735027;
    } else {
        return plane_sdf(abs(p), vec3(1.0), s);
    }
}

fn sphere_sdf(p: vec3<f32>, c: vec3<f32>, r: f32) -> f32 {
    return length(p - c) - r;
}

fn box_sdf(p_in: vec3<f32>, c: vec3<f32>, d: vec3<f32>, t: f32) -> f32 {
    // 平行移動
    let p = abs(p_in - c);

    return length(max(p - d, vec3(0.0))) + min(max(max(p.x - d.x, p.y - d.y), p.z - d.z), 0.0) - t;
}

fn smin(a: f32, b: f32, k: f32) -> f32 {
    let h = saturate(0.5 + 0.5 * (b - a)/ k);
    return mix(b, a, h) - k * h * (1.0 - h);
}

fn sdf_(p: vec3<f32>, f: f32) -> f32 {
    let r = 0.2;
    // 折りたたまれた座標に配置された球
    let d1 = sphere_sdf(fract(p + 0.5) - 0.5, vec3(0.0), r);
    // 原点を中心にした八面体
    let d2_prev = octahedron_sdf_(p,  max(f - 1.0, 0.0)) - r - 0.01;
    let d2_cur = octahedron_sdf_(p,  f) - r - 0.01;
    let d2_next = octahedron_sdf_(p,  f + 1.0) - r - 0.01;

    let settled = max(d1, d2_prev);
    let cur_edge = max(d1, max(d2_cur, -d2_prev));
    let next_edge = max(d1, max(d2_next, -d2_cur));

    return min(settled, mix(cur_edge, next_edge, fract(globals.time * SPEED)));
}

fn sdf(p: vec3<f32>) -> f32 {
    let f = f32(globals.time) * SPEED;
    let phase = floor(f);
    let d1 = sdf_(p, phase);
    let d2 = sdf_(p, phase + 1.0);

    return d1;

    // return smin(d1, d2, pow(fract(f), 2.0));
}

fn grad_sdf(p: vec3<f32>) -> vec3<f32> {
    let eps = 0.001;
    return normalize(vec3(
        sdf(p + vec3(eps,  0.,  0.)) - sdf(p - vec3(eps,  0.,  0.)),
        sdf(p + vec3( 0., eps,  0.)) - sdf(p - vec3( 0., eps,  0.)),
        sdf(p + vec3( 0.,  0., eps)) - sdf(p - vec3( 0.,  0., eps))
    ));
}

//********** Main *********************************************//

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    var pos = (2.0 * in.pos.xy - globals.resolution) / min(globals.resolution.x, globals.resolution.y);

    // Y direction is upside down
    pos.y = -pos.y;

    // position of the camera
    let t = vec3(0.1 * globals.time);
    let camera_pos = euler(vec3( 0.0,  0.0,  2.0 + pow(globals.time * SPEED, 0.8)), t);
    let camera_dir = euler(vec3( 0.0,  0.0, -1.0), t);
    let camera_up  = euler(vec3( 0.0,  1.0,  0.0), t);
    let light_dir  = euler(vec3( 0.0,  0.0,  1.0), t);
    // screen
    let camera_side = cross(camera_dir, camera_up);

    let target_depth = 1.0;

    var ray = (camera_side * pos.x + camera_up * pos.y + camera_dir * target_depth);

    // initial ray position
    var r = camera_pos + ray;

    ray = normalize(ray);

    var color = vec3(0.0);
    for (var i = 0; i < 50; i++) {
        // if the ray reacyhes near enough to the surface, stop there
        if sdf(r) < 0.001 {
            let ambient_light = 0.1;
            let diff = 0.9 * max(dot(light_dir, grad_sdf(r)), 0.0);

            let n = abs(round(r));
            if n.x + n.y + n.z == floor(globals.time * SPEED) {
                color = vec3(1.0, 0.0, 0.0) * (diff + ambient_light);
            } else {
                color = vec3(0.32, 0.82, 0.98) * (diff + ambient_light);
            }
        }
        // otherwise, move the ray forward
        r += sdf(r) * ray;
    }
    
    return vec4(color, 1.0);
}
