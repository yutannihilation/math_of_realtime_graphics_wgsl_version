struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
};

struct GlobalsUniform {
    @location(0) resolution: vec2<f32>,
    @location(1) time:       f32,
};

@group(0) @binding(0)
var<uniform> globals: GlobalsUniform;

let PI = 3.1415926;

// It seems WGSL's atan() works even on the point of x = 0
// 
// fn atan2_(y: f32, x: f32) -> f32 {
//     if (x == 0.0) {
//         return sign(y) * PI / 2.0;
//     } else {
//         return atan2(y, x);
//     }
// }

fn xy2pol(xy: vec2<f32>) -> vec2<f32> {
    return vec2(atan2(xy.y, xy.x), length(xy));
}

fn pol2xy(pol: vec2<f32>) -> vec2<f32> {
    return pol.y * vec2(cos(pol.x), sin(pol.x));
}

fn tex(st: vec2<f32>) -> vec3<f32> {
    let t = 0.2 * globals.time;
    let circ = vec3(pol2xy(vec2(t, 0.5)) + 0.5, 1.0);

    // It seems this cannot be declared in the module space with const- 
    // declaration. There seems at least two problems:
    //
    // 1. first of all, wgpu rejects all `const` keyword. Maybe it's not 
    //    supported yet?
    // 2. if we change this to let-declaration, we'll see "The expression
    //    [<line number>] may only be indexed by a constant" error, which
    //    I don't understand what's happening...
    // 
    var colors = array(circ.rgb, circ.gbr, circ.brg);

    let x = st.x / PI + 1.0 + t;
    let col = mix(
        colors[u32(i32(x) % 2)],
        colors[u32(i32(x + 1.0) % 2)],
        fract(x)
    );

    return mix(colors[2], col, st.y);
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    var pos = 2.0 * in.pos.xy / globals.resolution - 1.0;
    return vec4(tex(xy2pol(pos)), 1.0);
}
