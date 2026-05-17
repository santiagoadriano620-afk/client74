varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    if(texColor.a < 0.01)
        discard;

    gl_FragColor = vec4(0.0, 0.0, 0.0, texColor.a);
}
