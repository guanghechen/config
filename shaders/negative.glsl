// @see https://github.com/0xhckr/ghostty-shaders/blob/01738211b26a60eac33119d6da0c7bb12763e683/negative.glsl


void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 color = texture(iChannel0, uv);
    fragColor = vec4(1.0 - color.x, 1.0 - color.y, 1.0 - color.z, color.w);
}