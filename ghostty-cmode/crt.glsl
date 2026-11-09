// cmode's CRT pass for Ghostty: cool-retro-term's look, set to match the
// profile in ~/dotfiles/cool_retro_term.json (basse_terminal):
//   fontColor #c0c0c0, backgroundColor #000000, chromaColor 0.5,
//   saturationColor 0, brightness 0.6, contrast 1, frameSize 0.1,
//   screenRadius 0.1, ambientLight 0, and every animated effect at 0.
// The maths follows cool-retro-term's terminal_static.frag,
// terminal_dynamic.frag, TerminalFrame.qml and ApplicationSettings.qml.

// fontColor after saturation 0 and contrast 1 leave it as is
const vec3 FONT_COLOR = vec3(0.753);
const vec3 BACKGROUND = vec3(0.0);
// how much of the real colour survives (0 = monochrome in FONT_COLOR)
const float CHROMA = 0.5;
// brightness 0.6 -> lint(0.5, 1.5, 0.6)
const float BRIGHTNESS = 1.1;
// screenRadius 0.1 -> lint(4, 120, 0.1) pixels
const float SCREEN_RADIUS = 15.6;
// frameSize 0.1 -> 0.1 * 0.05 of the window on each side
const float FRAME_SIZE = 0.005;
// the frame with no ambient light: mostly a dimmed font colour
const vec3 FRAME_COLOR = vec3(0.23);

float rgb2grey(vec3 v) { return dot(v, vec3(0.21, 0.72, 0.04)); }
float rand2(vec2 v) { return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 c = texture(iChannel0, uv).rgb;

    // static pass: brightness and a faint fixed grain
    c *= BRIGHTNESS;
    c = clamp(c + vec3((rand2(uv) - 0.5) * 0.025), 0.0, 1.0);

    // dynamic pass: colour through the phosphor (convertWithChroma)
    float grey = rgb2grey(c);
    vec3 fg = mix(FONT_COLOR, c * FONT_COLOR / max(grey, 0.0001), CHROMA);
    vec3 col = mix(BACKGROUND, fg, grey);

    // frame: the screen is a rounded rectangle inset by FRAME_SIZE
    vec2 size = iResolution.xy;
    vec2 half_screen = size * (0.5 - FRAME_SIZE);
    vec2 q = abs(fragCoord - size * 0.5) - (half_screen - SCREEN_RADIUS);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - SCREEN_RADIUS;
    float screen = clamp(0.5 - d, 0.0, 1.0);
    col = mix(FRAME_COLOR, col, screen);

    fragColor = vec4(col, 1.0);
}
