// todo: use expression directly when supported in naga
const DIV12: f32 = 0.0773993808;// 1.0 / 12.92
const DIV1: f32 = 0.94786729857; // 1.0 / 1.055
const THRESHOLD: f32 = 0.04045;
const GAMMA: vec3f = vec3f(2.4);

// Convert from limited colors to full
const LIMITED_MIN: f32 = 0.06274509803; // 16.0 / 255.0
const LIMITED_MAX: f32 = 0.92156862745; // 235.0 / 255.0

override FIX_LIMITED_RANGE: bool;
override ENABLE_SRGB_CORRECTION: bool;
override ENCODING_GAMMA: f32;

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) uv: vec2f,
}

@group(0) @binding(0) var stream_texture: texture_2d<f32>;
@group(0) @binding(1) var stream_sampler: sampler;

@vertex
fn vertex_main(@builtin(vertex_index) vertex_index: u32) -> VertexOutput {
    var result: VertexOutput;

    result.uv = vec2f(f32(vertex_index & 1), f32(vertex_index >> 1));
    result.position = pc.reprojection_transform * vec4f(result.uv.x - 0.5, 0.5 - result.uv.y, 0.0, 1.0);

    return result;
}

@fragment
fn fragment_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    var result: vec3f = textureSample(stream_texture, stream_sampler, uv).rgb;

    if FIX_LIMITED_RANGE {
        // For some reason, the encoder shifts full-range color into the negatives and over one.
        color = LIMITED_MIN + ((LIMITED_MAX - LIMITED_MIN) * color);
    }

    if ENABLE_SRGB_CORRECTION {
        let condition = vec3f(f32(color.r < THRESHOLD), f32(color.g < THRESHOLD), f32(color.b < THRESHOLD));
        let lowValues = color * DIV12;
        let highValues = pow((color + vec3f(0.055)) * DIV1, GAMMA);
        color = condition * lowValues + (1.0 - condition) * highValues;
    }

    if ENCODING_GAMMA != 0.0 {
        let enc_condition = vec3f(f32(color.r < 0.0), f32(color.g < 0.0), f32(color.b < 0.0));
        let enc_lowValues = color;
        let enc_highValues = pow(color, vec3f(ENCODING_GAMMA));
        color = enc_condition * enc_lowValues + (1.0 - enc_condition) * enc_highValues;
    }

    return vec4f(color, COLOR_ALPHA);
}
