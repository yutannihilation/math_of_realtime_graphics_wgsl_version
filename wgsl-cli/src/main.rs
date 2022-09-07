use std::{fs, process::exit};

use argh::FromArgs;

use wgpu::{include_wgsl, util::DeviceExt};

use winit::{
    dpi::PhysicalSize,
    event::*,
    event_loop::{ControlFlow, EventLoop},
    window::{Window, WindowBuilder},
};

// window size
const DEFAULT_HEIGHT: f64 = 1000.0;
const DEFAULT_WIDTH: f64 = 1000.0;

// logging
const DEFAULT_LOG_LEVEL: &str = "info";

#[repr(C)]
#[derive(Copy, Clone, Debug, bytemuck::Pod, bytemuck::Zeroable)]
struct Vertex {
    position: [f32; 2],
}

impl Vertex {
    const ATTRIBS: [wgpu::VertexAttribute; 1] = wgpu::vertex_attr_array![0 => Float32x2];

    fn desc<'a>() -> wgpu::VertexBufferLayout<'a> {
        wgpu::VertexBufferLayout {
            array_stride: std::mem::size_of::<Self>() as wgpu::BufferAddress,
            step_mode: wgpu::VertexStepMode::Vertex,
            attributes: &Self::ATTRIBS,
        }
    }
}

#[rustfmt::skip]
const RECT_VERTICES: &[Vertex] = &[
    Vertex { position: [ 1.0, -1.0] },
    Vertex { position: [-1.0, -1.0] },
    Vertex { position: [-1.0,  1.0] },
    Vertex { position: [ 1.0,  1.0] },
];
const RECT_INDICES: &[u16] = &[0, 1, 2, 0, 2, 3];

#[repr(C)]
#[derive(Copy, Clone, Debug, bytemuck::Pod, bytemuck::Zeroable)]
struct Globals {
    resolution: [f32; 2],
    time: f32,
    _padding: u32,
    // frame: u32,
    // mouse_pos: [f32; 2],
}

struct State {
    surface: wgpu::Surface,
    device: wgpu::Device,
    queue: wgpu::Queue,

    config: wgpu::SurfaceConfiguration,

    size: winit::dpi::PhysicalSize<u32>,

    start_time: std::time::Instant,
    last_time_elapsed: f32,
    frame: u32,

    vertex_buffer: wgpu::Buffer,
    index_buffer: wgpu::Buffer,
    globals_bind_group: wgpu::BindGroup,
    globals_uniform_buffer: wgpu::Buffer,

    render_pipeline: wgpu::RenderPipeline,
}

impl State {
    async fn new(window: &Window, frag_shader_code: String) -> Self {
        let size = window.inner_size();

        let instance = wgpu::Instance::new(wgpu::Backends::all());
        let surface = unsafe { instance.create_surface(window) };
        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::default(),
                force_fallback_adapter: false,
                compatible_surface: Some(&surface),
            })
            .await
            .unwrap();

        let (device, queue) = adapter
            .request_device(
                &wgpu::DeviceDescriptor {
                    label: Some("Device Descriptor"),
                    features: wgpu::Features::empty(), // TODO
                    limits: wgpu::Limits::default(),
                },
                None,
            )
            .await
            .unwrap();

        let config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format: surface.get_supported_formats(&adapter)[0],
            width: size.width,
            height: size.height,
            present_mode: wgpu::PresentMode::Fifo,
        };

        surface.configure(&device, &config);

        let vert_shader = device.create_shader_module(include_wgsl!("vert.wgsl"));
        let frag_shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("Shader"),
            source: wgpu::ShaderSource::Wgsl(frag_shader_code.into()),
        });

        let vertex_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Vertex buffer"),
            contents: bytemuck::cast_slice(RECT_VERTICES),
            usage: wgpu::BufferUsages::VERTEX,
        });

        let index_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Index buffer"),
            contents: bytemuck::cast_slice(RECT_INDICES),
            usage: wgpu::BufferUsages::INDEX,
        });

        let globals_uniform_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("Uniform buffer for globals"),
            size: std::mem::size_of::<Globals>() as _,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let globals_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("Globals bind group layout"),
                entries: &[wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                }],
            });

        let globals_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("wgpugd globals bind group"),
            layout: &globals_bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: globals_uniform_buffer.as_entire_binding(),
            }],
        });

        let render_pipeline_layout =
            device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
                label: Some("Render Pipeline Layout"),
                bind_group_layouts: &[&globals_bind_group_layout],
                push_constant_ranges: &[],
            });

        let render_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("Render Pipeline"),
            layout: Some(&render_pipeline_layout),
            vertex: wgpu::VertexState {
                module: &vert_shader,
                entry_point: "vs_main",
                buffers: &[Vertex::desc()],
            },
            fragment: Some(wgpu::FragmentState {
                module: &frag_shader,
                entry_point: "fs_main",
                targets: &[Some(wgpu::ColorTargetState {
                    format: config.format,
                    blend: Some(wgpu::BlendState::REPLACE),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleList,
                strip_index_format: None,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: None, // TODO: what's the correct value here?
                unclipped_depth: false,
                polygon_mode: wgpu::PolygonMode::Fill,
                conservative: false,
            },
            // we don't use depth
            depth_stencil: None,
            // we don't use multisample
            multisample: wgpu::MultisampleState {
                count: 1,
                ..Default::default()
            },
            // we don't use aray textures
            multiview: None,
        });

        Self {
            surface,
            device,
            queue,
            config,
            size,

            start_time: std::time::Instant::now(),
            last_time_elapsed: 1.0,
            frame: 0,

            vertex_buffer,
            index_buffer,
            globals_bind_group,
            globals_uniform_buffer,
            render_pipeline,
        }
    }

    // Don't implement resize for simplicity
    //
    // fn resize(&mut self, new_size: winit::dpi::PhysicalSize<u32>) {}

    fn input(&mut self, event: &WindowEvent) -> bool {
        false
    }

    fn update(&mut self) {
        // TODO;
    }

    fn render(&mut self) -> Result<(), wgpu::SurfaceError> {
        self.frame += 1;
        let time = self.start_time.elapsed().as_secs_f32();

        if self.frame % 10 == 0 {
            log::info!(
                "frame: {} (fps: {:.3})",
                self.frame,
                10. / (time - self.last_time_elapsed)
            );

            self.last_time_elapsed = time;
        }

        let output = self.surface.get_current_texture()?;
        let view = output
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());
        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("Render Encoder"),
            });

        self.queue.write_buffer(
            &self.globals_uniform_buffer,
            0,
            bytemuck::cast_slice(&[Globals {
                resolution: [self.size.width as _, self.size.height as _],
                // todo
                time,
                _padding: 0,
                // frame: self.frame,
                // mouse_pos: [0.0, 0.0],
            }]),
        );

        {
            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("Render Pass Descriptor"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &view,
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::WHITE),
                        store: true,
                    },
                })],
                depth_stencil_attachment: None,
            });

            render_pass.set_pipeline(&self.render_pipeline);
            render_pass.set_bind_group(0, &self.globals_bind_group, &[]);
            render_pass.set_vertex_buffer(0, self.vertex_buffer.slice(..));
            render_pass.set_index_buffer(self.index_buffer.slice(..), wgpu::IndexFormat::Uint16);
            render_pass.draw_indexed(0..RECT_INDICES.len() as _, 0, 0..1);
        }

        self.queue.submit(std::iter::once(encoder.finish()));
        output.present();

        Ok(())
    }
}

async fn run(frag_shader_code: String, width: f64, height: f64) {
    let env = env_logger::Env::default().default_filter_or(DEFAULT_LOG_LEVEL);
    env_logger::Builder::from_env(env).init();

    let event_loop = EventLoop::new();
    let window = WindowBuilder::new()
        .with_inner_size(PhysicalSize::new(width, height)) // fixed size
        .with_resizable(false)
        .build(&event_loop)
        .unwrap();

    let mut state = State::new(&window, frag_shader_code).await;

    event_loop.run(move |event, _, control_flow| match event {
        Event::WindowEvent {
            window_id,
            ref event,
        } if window_id == window.id() => {
            if !state.input(event) {
                match event {
                    WindowEvent::CloseRequested
                    | WindowEvent::KeyboardInput {
                        input:
                            KeyboardInput {
                                state: ElementState::Pressed,
                                virtual_keycode: Some(VirtualKeyCode::Escape),
                                ..
                            },
                        ..
                    } => *control_flow = ControlFlow::Exit,
                    _ => {}
                }
            }
        }
        Event::RedrawRequested(window_id) if window_id == window.id() => {
            state.update();
            match state.render() {
                Ok(_) => {}
                Err(wgpu::SurfaceError::Lost | wgpu::SurfaceError::OutOfMemory) => {
                    *control_flow = ControlFlow::Exit;
                }
                Err(e) => eprintln!("{:?}", e),
            }
        }
        // According to the [doc],
        //
        // > If your program only draws graphics when something changes, it’s
        // > usually better to do it in response to Event::RedrawRequested,
        // > which gets emitted immediately after this event. Programs that draw
        // > graphics continuously, like most games, can render here
        // > unconditionally for simplicity.
        //
        // [doc]:
        //     https://docs.rs/winit/latest/winit/event/enum.Event.html#variant.MainEventsCleared
        Event::MainEventsCleared => {
            window.request_redraw();
        }
        _ => {}
    });
}

#[derive(FromArgs, Debug)]
/// Reach new heights.
struct CliOptions {
    /// width of the window
    #[argh(option, short = 'w', default = "DEFAULT_WIDTH")]
    width: f64,

    /// height of the window
    #[argh(option, short = 'h', default = "DEFAULT_HEIGHT")]
    height: f64,

    /// path to fragment shader
    #[argh(positional)]
    frag_shader: String,
}

fn main() {
    let opts: CliOptions = argh::from_env();
    // println!("{:#?}", opts);

    let res = fs::read_to_string(opts.frag_shader);
    if res.is_err() {
        eprintln!("{:?}", res);
        exit(1);
    }

    let frag_shader_code = res.unwrap();

    pollster::block_on(run(frag_shader_code, opts.width, opts.height));
}
