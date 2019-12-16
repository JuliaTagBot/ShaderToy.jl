 #version 450
in vec2 fragCoord;
out vec4 fragColor;

uniform vec2  iResolution;
uniform float iTime;
uniform float iTimeDelta;
uniform int   iFrame;
uniform float iFrameRate;
void main()
{
    fragColor = vec4(1.0, 0.0, 1.0, 1.0);
}