shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform bool wisps = false;
uniform bool reverse_sweep = false;
void fragment() {
    float u = reverse_sweep ? 1.0-UV.x : UV.x;
    float v = abs(UV.y-.5)*2.0;
    float jag = sin(UV.x*91.0+progress*12.0)*sin(UV.x*37.0-progress*8.0);
    float core = exp(-v*v*42.0);
    float halo = exp(-v*v*7.0);
    float filaments = pow(max(0.0,sin(UV.x*130.0+UV.y*28.0+progress*19.0)),6.0);
    float reveal = 1.0-smoothstep(progress*4.0-.12,progress*4.0+.12,u);
    float tip = pow(max(0.0,sin(UV.x*3.141593)),.45);
    float fade = pow(1.0-progress,1.6);
    float strength = wisps ? halo*(.22+filaments*.35)*(0.7+jag*.3) : core*2.2+halo*.48;
    ALBEDO = wisps ? vec3(.65,.002,.012) : mix(vec3(.8,.004,.014),vec3(1.0,.20,.12),core*.6);
    ALPHA = clamp(strength*reveal*tip*fade,0.0,1.0);
}
