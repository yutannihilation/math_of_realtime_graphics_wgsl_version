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

fn voronoi2(p: vec2<f32>) -> vec2<f32> {
    let n = floor(p + 0.5); // nearest lattice point
    var dist = sqrt(2.0);
    var id = vec2(0.0);

    for (var j = 0.0; j <= 2.0; j += 1.0) {
        var grid: vec2<f32>; // near lattice point
        grid.y = n.y + sign(j % 2.0 - 0.5) * ceil(j * 0.5);
        if (abs(grid.y - p.y) - 0.5 > dist) {
            continue;
        }
        for (var i = -1.0; i <= 1.0; i += 1.0) {
            grid.x = n.x + i;
            let jitter = hash22(grid) - 0.5;
            let len = length(grid + jitter - p);
            if len < dist {
                dist = len;
                id = grid;
            }
        }
    }

    return id;
}

fn voronoi3(p: vec3<f32>) -> vec3<f32> {
    let n = floor(p + 0.5); // nearest lattice point
    var dist = sqrt(3.0);
    var id = vec3(0.0);

    for (var k = 0.0; k <= 2.0; k += 1.0) {
        var grid: vec3<f32>; // near lattice point
        grid.z = n.z + sign(k % 2.0 - 0.5) * ceil(k * 0.5);
        if (abs(grid.z - p.z) - 0.5 > dist) {
            continue;
        }
        for (var j = 0.0; j <= 2.0; j += 1.0) {
            grid.y = n.y + sign(j % 2.0 - 0.5) * ceil(j * 0.5);
            if (abs(grid.y - p.y) - 0.5 > dist) {
                continue;
            }
            for (var i = -1.0; i <= 1.0; i += 1.0) {
                grid.x = n.x + i;
                let jitter = hash33(grid) - 0.5;
                let len = length(grid + jitter - p);
                if len < dist {
                    dist = len;
                    id = grid;
                }
            }
        }
    }

    return id;
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

    if globals.channel == 0u {
        return vec4(vec3(hash22(voronoi2(pos)), 1.0), 1.0);
    } else {
        return vec4(vec3(hash33(voronoi3(vec3(pos, 0.33 * globals.time)))), 1.0);
    }
}
