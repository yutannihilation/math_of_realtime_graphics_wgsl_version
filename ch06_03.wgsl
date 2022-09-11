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

fn mod2(x: f32, y: f32) -> f32 {
    return x - y * floor(x / y);
}

//********** Cellular Noise *********************************************//

fn sort(p: vec4<f32>, v: f32) -> vec4<f32> {
    let b = p <= vec4(v);

    // If all values are larget than v, do not modify dist.
    // Otherwise, insert v
    if all(b) {
        return p;
    } else if !b[0] {
        return vec4(v, p.xyz);
    } else if !b[1] {
        return vec4(p.x, v, p.yz);
    } else if !b[2] {
        return vec4(p.xy, v, p.z);
    } else {
        return vec4(p.xyz, v);
    }
}

fn fdist24(p: vec2<f32>) -> vec4<f32> {
    let n = floor(p + 0.5); // nearest lattice point
    var dist = vec4(length(1.5 - abs(p - n)));

    for (var j = 0.0; j <= 4.0; j += 1.0) {
        var grid: vec2<f32>; // near lattice point
        grid.y = n.y + sign(j % 2.0 - 0.5) * ceil(j * 0.5);
        if (abs(grid.y - p.y) - 0.5 > dist.w) {
            continue;
        }
        for (var i = -2.0; i <= 2.0; i += 1.0) {
            grid.x = n.x + i;
            let jitter = hash22(grid) - 0.5;
            let len = length(grid + jitter - p);
            dist = sort(dist, len);
        }
    }

    return dist;
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
    pos = 10.0 * pos + 0.2 * globals.time;

    var m = mat3x4(
        vec4(0.2),
        vec4( 0.5, -1.0,  1.4, -0.1),
        vec4(-0.3, -0.5, -1.2,  1.0)
    );

    let f = fdist24(pos);
    let wt = mix(vec4(0.2), vec4( 0.5, -1.0,  1.4, -0.1), 0.5 + 0.2 * vec4(sin(globals.time / 4.0), sin(globals.time / 8.0), sin(globals.time / 2.0), sin(globals.time)));
    return vec4(vec3(abs(dot(f, wt))), 1.0);
}
