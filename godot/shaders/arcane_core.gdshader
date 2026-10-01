shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform vec4 accent : source_color = vec4(0.15,0.3,1.0,1.0);
uniform vec4 tone : source_color = vec4(0.28,0.55,1.0,1.0);
void fragment() {
 vec2 p=UV*vec2(18.0,12.0);
 float swirl=sin(p.x+sin(p.y*1.4-TIME*3.0)*2.0+TIME*2.5);
 float veins=pow(1.0-abs(sin(p.y+swirl*2.3-TIME*2.0)),7.0);
 float rim=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),2.0);
 ALBEDO=mix(tone.rgb*0.3,tone.rgb*1.5,0.35+swirl*0.15)+mix(tone.rgb,vec3(1.0),0.35)*(veins*0.9+rim*0.45)+accent.rgb*swirl*0.12;
}
