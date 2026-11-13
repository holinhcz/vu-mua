shader_type canvas_item;
// Lò bánh mì: the xẻng (peel + loaf) slides in and out by `ins` units; it is hidden wherever the scene is nearer
// the viewer (depth test), so the arch, the inner walls of the mouth and the post cover it in the right places.
// Use the same shader on 2 Sprite2D (centered = false, position = footprint centre + rest_rect.xy + step * ins):
//   lobanhmi_xeng_<d|n>      is_shade = false, rest_rect = atlas "xeng<d|n>"
//   lobanhmi_xengbong_<d|n>  is_shade = true,  rest_rect = atlas "xengbong<d|n>"  (texture_filter = NEAREST)
// ins = xeng_move.ins * (0.5 - 0.5 * cos(TAU * t / xeng_move.period)), set every frame on both.
// Import lobanhmi_xengdo, lobanhmi_canhdo, lobanhmi_xengbong_* as Lossless, no mipmaps (they carry 16-bit depth in R,G).
uniform float ins = 0.0;
uniform vec4 rest_rect;                 // x, y, w, h in game units (atlas)
uniform vec4 canh_rect;                 // atlas "canhdo"
uniform vec2 step;                      // atlas xeng_move.step: game units moved per unit of ins
uniform float dk;                       // atlas xeng_move.dk: depth lost per unit of ins
uniform float d0;                       // atlas xeng_move.d0
uniform float dr;                       // atlas xeng_move.dr
uniform bool is_shade = false;
uniform sampler2D canh_do : filter_nearest;
uniform sampler2D xeng_do : filter_nearest;

float dec(vec4 t) { return d0 + (floor(t.r * 255.0 + 0.5) * 256.0 + floor(t.g * 255.0 + 0.5)) / 65535.0 * dr; }

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    vec2 p = rest_rect.xy + UV * rest_rect.zw + step * ins;      // where this pixel is now, game units from the footprint centre
    vec2 cu = (p - canh_rect.xy) / canh_rect.zw;
    vec4 sc = texture(canh_do, cu);
    bool has = sc.a > 0.5 && cu.x >= 0.0 && cu.y >= 0.0 && cu.x <= 1.0 && cu.y <= 1.0;
    float ds = dec(sc);
    if (is_shade) {
        float d = dec(c) - ins * dk;                             // the shade lies on the bậu: same plane, slides with the peel
        COLOR = vec4(0.0, 0.0, 0.0, (has && abs(d - ds) < 0.6) ? c.a : 0.0);
    } else {
        float d = dec(texture(xeng_do, UV)) - ins * dk;
        COLOR = vec4(c.rgb, (!has || d > ds) ? c.a : 0.0);
    }
}
