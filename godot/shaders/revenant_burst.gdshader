shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float progress = 0.0;
uniform bool wisps = false;
void fragment() {
    float u=UV.x;
    float bend=sin(u*47.0)*sin(u*19.0+1.3)*.16;
    float v=abs(UV.y-.5+bend)*2.0;
    float vein=exp(-v*v*36.0);
    float body=(1.0-smoothstep(.35,.95,v));
    float rag=0.65+0.35*sin(u*91.0+UV.y*25.0)*sin(u*37.0-UV.y*13.0);
    float reveal=1.0-smoothstep(progress*6.0-.1,progress*6.0+.1,u);
    float fade=1.0-smoothstep(.3,1.0,progress);
    ALBEDO=mix(vec3(.11,.001,.006),vec3(.62,.008,.026),vein);
    EMISSION=vec3(.48,.002,.015)*vein*.45;
    ALPHA=body*rag*reveal*fade*(wisps ? .32 : .9);
}
