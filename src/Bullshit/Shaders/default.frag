#version 330

out vec4 frag_color;
in vec4 vertex_color;
uniform vec4 our_color;

void main() {
    frag_color = our_color;
}
