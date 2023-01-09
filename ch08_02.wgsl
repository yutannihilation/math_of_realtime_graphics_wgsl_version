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
        sin(t) * p.x - cos(t) * p.y
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

fn tex(st: vec2<f32>) -> f32 {
    let f = mod2(floor(st.x) + floor(st.y), 2.0);
    return warp21(st * (0.6 + f), 1.0) * (0.6 + 0.3 * f);
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
    var pos = 2.0 * in.pos.xy / min(globals.resolution.x, globals.resolution.y) - 1.0;

    // Y direction is upside down
    pos.y = 1.0 - pos.y;

    // position of the camera
    let camera_pos = vec3(0.0);

    let t = -0.5 * PI * (1.0 - globals.mouse.y / globals.resolution.y);

    let camera_dir = rotX(vec3( 0.,  0., -1.), t);
    let camera_up  = rotX(vec3( 0.,  1.,  0.), t);

    // screen
    let camera_side = cross(camera_dir, camera_up);

    let target_depth = 1.0;

    // the vector between the position on the screen and the camera
    var ray = (camera_side * pos.x + camera_up * pos.y + camera_dir * target_depth) - camera_pos;
    ray = normalize(ray);
    
    let ground_normal = vec3(0.0, 1.0, 0.0);
    
    let ground_height = 1.0 + (globals.mouse.x / globals.resolution.x);

    let light_pos = vec3(0.0);

    if (dot(ray, ground_normal) < 0.0) {
        let hit = camera_pos - ray * ground_height / dot(ray, ground_normal);
        var diff = max(dot(normalize(light_pos - hit), ground_normal), 0.0);
        diff *= (1.5 - globals.mouse.y / globals.resolution.y);
        diff = pow(diff, 0.5 + globals.mouse.x / globals.resolution.x);
        return vec4(diff * vec3(tex(hit.zx)), 1.0);
    } else {
        return vec4(vec3(0.0), 1.0);
    }
}
