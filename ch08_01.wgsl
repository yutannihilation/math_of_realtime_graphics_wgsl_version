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

//********** Texture *********************************************//

fn tex(st: vec2<f32>) -> f32 {
    return mod2(floor(st.x) + floor(st.y), 2.0);
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

    if (dot(ray, ground_normal) < 0.0) {
        let hit = camera_pos - ray * ground_height / dot(ray, ground_normal);
        return vec4(vec3(tex(hit.zx)), 1.0);
    } else {
        return vec4(vec3(0.0), 1.0);
    }
}
