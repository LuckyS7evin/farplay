// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — post-traitement des couleurs (F7) : contraste, saturation, vibrance.
// Appliqué aux images reçues (avant la frame gen), en RGB encodé (sRGB ou PQ).
// Contraste autour d'un gris moyen sur la luminance, saturation et vibrance sur
// l'écart à la luminance (teinte conservée). La vibrance renforce surtout les
// couleurs ternes et épargne les couleurs déjà saturées (peau, ciel vif).

//!PARAM farplay_contrast
//!DESC Contraste (-0.5 .. 0.5)
//!TYPE float
//!MINIMUM -0.5
//!MAXIMUM 0.5
0.0

//!PARAM farplay_saturation
//!DESC Saturation (-0.5 .. 0.5)
//!TYPE float
//!MINIMUM -0.5
//!MAXIMUM 0.5
0.0

//!PARAM farplay_vibrance
//!DESC Vibrance (0 .. 1)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.0

//!PARAM farplay_pivot
//!DESC Gris moyen du contraste (valeur encodée)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.45

//!HOOK MAIN
//!BIND HOOKED
//!DESC Farplay post-traitement couleur

vec4 hook()
{
    vec4 c = HOOKED_tex(HOOKED_pos);
    const vec3 kw = vec3(0.2627, 0.6780, 0.0593);
    float y = dot(c.rgb, kw);
    // Contraste sur la luminance, la couleur suit (rapport conservé)
    float y2 = max(farplay_pivot + (y - farplay_pivot) * (1.0 + farplay_contrast), 0.0);
    vec3 rgb = c.rgb + (y2 - y);
    // Saturation globale puis vibrance pondérée par la saturation existante
    vec3 d = rgb - y2;
    float sat = max(rgb.r, max(rgb.g, rgb.b)) - min(rgb.r, min(rgb.g, rgb.b));
    float boost = (1.0 + farplay_saturation) * (1.0 + farplay_vibrance * (1.0 - smoothstep(0.0, 0.6, sat)));
    rgb = y2 + d * boost;
    c.rgb = clamp(rgb, 0.0, 1.0);
    return c;
}
