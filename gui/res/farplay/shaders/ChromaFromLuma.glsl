// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay : reconstruction de la couleur (chroma 4:2:0) guidée par la luminance.
//
// Le flux transporte la couleur à demi-résolution (960x540 pour 1080p) : les
// bords colorés (HUD, textes, néons) bavent. Autour de chaque pixel, on ajuste
// localement une relation linéaire chroma = a * luma + b sur les 4x4 échantillons
// de chroma voisins (la luminance étant lue aux mêmes positions physiques), puis
// on prédit la chroma à pleine résolution avec la luminance du pixel.
// La prédiction n'est retenue qu'en proportion de la corrélation locale (r²)
// et reste bornée par les chromas voisines : pas de couleur inventée.

//!PARAM farplay_cfl_strength
//!DESC Farplay : poids maximal de la prédiction (0 = bilinéaire seul)
//!TYPE DYNAMIC float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.9

//!HOOK CHROMA
//!BIND HOOKED
//!BIND LUMA
//!WIDTH LUMA.w
//!HEIGHT LUMA.h
//!WHEN CHROMA.w LUMA.w <
//!OFFSET ALIGN
//!DESC Farplay chroma guidee par la luminance

vec4 hook()
{
    // Position (texels de chroma) du pixel de sortie et texel de chroma en haut à gauche du 4x4.
    vec2 cpos = HOOKED_pos * HOOKED_size - 0.5;
    vec2 base = floor(cpos) - 1.0;
    vec2 frac_c = cpos - floor(cpos);

    float y_full = LUMA_tex(LUMA_pos).x;

    float ws = 0.0, my = 0.0;
    vec2 mc = vec2(0.0);
    float syy = 0.0;
    vec2 syc = vec2(0.0), scc = vec2(0.0);
    vec2 cmin = vec2(1e6), cmax = vec2(-1e6);
    vec2 yc[16];
    float yv[16];
    float wv[16];

    for (int j = 0; j < 4; j++) {
        for (int i = 0; i < 4; i++) {
            vec2 tc = base + vec2(float(i), float(j)) + 0.5; // centre du texel (texels de chroma)
            vec2 cp = tc * HOOKED_pt;
            vec2 c = HOOKED_tex(cp).xy;
            // Même point physique dans la texture de luminance (les décalages
            // de site de chroma s'annulent dans la différence de positions).
            float y = LUMA_tex(LUMA_pos + (cp - HOOKED_pos)).x;
            vec2 d = tc - cpos;
            float w = exp(-0.5 * dot(d, d));
            int k = j * 4 + i;
            yc[k] = c; yv[k] = y; wv[k] = w;
            ws += w; my += w * y; mc += w * c;
            if (i >= 1 && i <= 2 && j >= 1 && j <= 2) {
                cmin = min(cmin, c);
                cmax = max(cmax, c);
            }
        }
    }
    my /= ws;
    mc /= ws;
    for (int k = 0; k < 16; k++) {
        float dy = yv[k] - my;
        vec2 dc = yc[k] - mc;
        syy += wv[k] * dy * dy;
        syc += wv[k] * dy * dc;
        scc += wv[k] * dc * dc;
    }
    syy /= ws; syc /= ws; scc /= ws;

    vec2 a = syc / (syy + 1e-5);
    vec2 pred = mc + a * (y_full - my);
    vec2 r2 = clamp((syc * syc) / (syy * scc + 1e-7), 0.0, 1.0);

    // Bilinéaire classique depuis les 4 voisins centraux.
    vec2 c00 = yc[5], c10 = yc[6], c01 = yc[9], c11 = yc[10];
    vec2 bil = mix(mix(c00, c10, frac_c.x), mix(c01, c11, frac_c.x), frac_c.y);

    // Marge de 10 % de l'étendue locale pour ne pas écrêter les vrais contours.
    vec2 pad = 0.1 * (cmax - cmin);
    pred = clamp(pred, cmin - pad, cmax + pad);
    vec2 wgt = farplay_cfl_strength * r2;
    return vec4(mix(bil, pred, wgt), 0.0, 1.0);
}
