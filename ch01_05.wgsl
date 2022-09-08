struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
};

struct GlobalsUniform {
    @location(0) resolution: vec2<f32>,
    @location(1) time:       f32,
};

@group(0) @binding(0)
var<uniform> globals: GlobalsUniform;

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    var pos = in.pos.xy / globals.resolution;

    // It seems this cannot be declared in the module space with const- 
    // declaration. There seems at least two problems:
    //
    // 1. first of all, wgpu rejects all `const` keyword. Maybe it's not 
    //    supported yet?
    // 2. if we change this to let-declaration, we'll see "The expression
    //    [<line number>] may only be indexed by a constant" error, which
    //    I don't understand what's happening...
    // 
    var colors = array(
        vec3(1., 0., 0.),
        vec3(0., 0., 1.),
        vec3(0., 1., 0.),
        vec3(0., 1., 1.),
    );

    let n = 4.0;
    pos *= n;

    let thr = 0.25 * sin(globals.time);
    // NOTE: unlike GLSL, smoothstep(x, y, z) requires that x, y, and z are the same type
    pos = floor(pos) + smoothstep(vec2(0.25 + thr), vec2(0.75 - thr), fract(pos));

    // NOTE: pos /= n won't work. Why...?
    pos = pos / n;

    // This cannot be written as the following. Probably because `ind + 1`
    // might overflow?
    // 
    // let ind = u32(pos.x);
    // let color1 = colors[ind];
    // let color2 = colors[ind + 1];
    //
    return vec4(mix(mix(colors[0], colors[1], pos.x), mix(colors[2], colors[3], pos.x), pos.y), 1.0);
}
