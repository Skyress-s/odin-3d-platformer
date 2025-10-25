#version 330

out vec4 finalColor;

in vec2 fragTexCoord;
// in vec4 fragColor;
uniform sampler2D texture0;
uniform sampler2D depthTex;

vec4 lerp(vec4 a, vec4 b, float t) {
  return a + (b - a) * t;
}

float lin(float d,float zNear,float zFar) {
  return zNear * zFar / (zFar + d * (zNear - zFar));
}

void main() {
  vec2 uv = vec2(fragTexCoord.r, 1 - fragTexCoord.g);
  // vec3 diffuse = texture(texture0, uv).rgb;
  float d = texture(texture0, uv).r;
  
  float depth = 1-d;
  // d = ((d - 1) * 10) + 1;
  // float depth = d > 1 ? 0 : d;

  // float depth = d == 1 ? 0 : ((d - 1) * 10) + 1; //linearize(d, 0.01, 10000);


  depth = depth * depth;

  //finalColor = vec4(texture(texture0, vec2(fragTexCoord.r, 1-fragTexCoord.g)).rgb, 1.0);
  finalColor = vec4(depth, depth, depth, 1);
  //
  // vec4 fogCol = vec4(0.51, 0.73, 0.65, 1); // light blue
  //
  // // float fogStart = 0.0f  // start at camera, implement later
  // float fogEnd = 20.0; // 200m
  // float fogPow = 1.0;
  //
  // // unsigned normalized, remap gl_FragDepth 
  // float fogFactor = pow(clamp((gl_FragCoord.z / fogEnd), 0.0, 1.0), fogPow);
  //
  // float a = 0.5;
  // float b = gl_FragCoord.z * a
  // finalColor = vec4(gl_FragCoord.z * a, gl_FragCoord.z * a, gl_FragCoord.z * a, 1); //lerp(texture(texture0, vec2(fragTexCoord.r, 1-fragTexCoord.g)), fogCol, fogFactor);
}
