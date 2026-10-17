shader_type canvas_item;
render_mode unshaded;
void fragment() {
    float density = texture(TEXTURE, UV).a;
    float body = smoothstep(0.42, 0.57, density);
    float rim = 1.0 - smoothstep(0.57, 0.83, density);
    vec3 deep = vec3(0.035, 0.36, 0.65);
    vec3 shallow = vec3(0.10, 0.77, 0.91);
    vec3 color = mix(shallow, deep, clamp(UV.y, 0.0, 1.0));
    color += vec3(0.28, 0.30, 0.30) * rim;
    COLOR = vec4(color, body * 0.96);
}
