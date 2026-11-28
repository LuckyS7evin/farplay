// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay : réduction des artefacts de compression du flux (blocs, bruit de
// quantification, ringing autour des contours), avant l'agrandissement.
//
// Non-local means allégé sur la luminance, à la résolution du flux :
// fenêtre de recherche 5x5, patchs 3x3, tuile en mémoire partagée.
// Les poids comparent des patchs entiers, donc les contours nets et les
// textures répétées sont conservés alors que le bruit isolé est moyenné.

//!PARAM farplay_denoise_h
//!DESC Farplay : force du filtre (écart de patch toléré, en valeur de code)
//!TYPE DYNAMIC float
//!MINIMUM 0.0
//!MAXIMUM 0.2
0.02

//!PARAM farplay_denoise_mix
//!DESC Farplay : part de l'image filtrée (1 = filtrée seule)
//!TYPE DYNAMIC float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.85

//!HOOK LUMA
//!BIND HOOKED
//!DESC Farplay reduction artefacts (NLM)
//!COMPUTE 16 16

#define FP_S 2
#define FP_P 1
#define FP_B (FP_S + FP_P)
#define FP_T (16 + 2 * FP_B)

shared float fp_tile[FP_T][FP_T];

void hook()
{
    ivec2 base = ivec2(gl_WorkGroupID.xy) * 16 - FP_B;
    for (uint i = gl_LocalInvocationIndex; i < uint(FP_T * FP_T); i += 256u) {
        ivec2 t = ivec2(int(i % uint(FP_T)), int(i / uint(FP_T)));
        vec2 pos = (vec2(base + t) + 0.5) * HOOKED_pt;
        fp_tile[t.y][t.x] = HOOKED_tex(pos).x;
    }
    barrier();

    ivec2 c = ivec2(gl_LocalInvocationID.xy) + FP_B;
    float center = fp_tile[c.y][c.x];
    float h2 = max(farplay_denoise_h * farplay_denoise_h, 1e-8);
    float inv = 1.0 / (h2 * float((2 * FP_P + 1) * (2 * FP_P + 1)));

    float sum = 0.0;
    float wsum = 0.0;
    float wmax = 0.0;
    for (int dy = -FP_S; dy <= FP_S; dy++) {
        for (int dx = -FP_S; dx <= FP_S; dx++) {
            if (dx == 0 && dy == 0)
                continue;
            float d = 0.0;
            for (int py = -FP_P; py <= FP_P; py++) {
                for (int px = -FP_P; px <= FP_P; px++) {
                    float a = fp_tile[c.y + py][c.x + px];
                    float b = fp_tile[c.y + dy + py][c.x + dx + px];
                    d += (a - b) * (a - b);
                }
            }
            float w = exp(-d * inv);
            sum += w * fp_tile[c.y + dy][c.x + dx];
            wsum += w;
            wmax = max(wmax, w);
        }
    }
    // Le pixel central compte comme son meilleur voisin (NLM classique).
    wmax = max(wmax, 1e-4);
    sum += wmax * center;
    wsum += wmax;
    float v = mix(center, sum / wsum, farplay_denoise_mix);

    ivec2 out_pos = ivec2(gl_GlobalInvocationID.xy);
    if (all(lessThan(out_pos, ivec2(HOOKED_size))))
        imageStore(out_image, out_pos, vec4(v, 0.0, 0.0, 1.0));
}
