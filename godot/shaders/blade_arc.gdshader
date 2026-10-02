shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float progress : hint_range(0.0,1.0) = 0.0;
void fragment() {
 float r=UV.y;
 float edge=smoothstep(0.84,0.96,r);
 float inner=smoothstep(0.55,0.8,r)*(1.0-smoothstep(0.82,0.92,r));
 float taper=mix(0.35,1.0,sin(UV.x*3.141593));
 float fade=pow(1.0-progress,1.25);
 float sweep=exp(-abs(UV.x-progress)*12.0);
 ALBEDO=mix(vec3(0.38,0.41,0.44),vec3(0.95,0.97,1.0),edge);
 ALPHA=(edge*0.78+inner*0.17+0.055)*(0.65+sweep*0.35)*taper*fade;
}
