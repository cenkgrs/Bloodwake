shader_type spatial;
render_mode cull_disabled;
uniform sampler2D body_texture : source_color, hint_default_white;
uniform vec4 body_tone : source_color = vec4(1.0);
uniform float progress : hint_range(0.0,1.0) = 0.0;
varying vec3 local_pos;
void vertex() { local_pos=VERTEX; }
float grain(vec3 p) {return fract(sin(dot(floor(p*28.0),vec3(17.13,63.71,29.31)))*43758.5453);}
void fragment() {
    vec4 skin=texture(body_texture,UV)*body_tone;
    float noise=grain(local_pos);
    float edge=smoothstep(progress,progress+.055,noise);
    float burn=(1.0-edge)*step(progress,noise)*step(.001,progress);
    ALBEDO=skin.rgb*(1.0-burn*.7);
    EMISSION=vec3(.8,.003,.025)*burn*2.0;
    ROUGHNESS=.8;
    ALPHA=skin.a*step(progress,noise)*(1.0-step(.999,progress));
    ALPHA_SCISSOR_THRESHOLD=.5;
}
