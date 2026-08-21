#include "gg_classifier.h"

static uint32_t popcount32(uint32_t x) {
    uint32_t n = 0;
    while (x) { n += x & 1u; x >>= 1; }
    return n;
}

static int32_t min32(int32_t a, int32_t b) { return a < b ? a : b; }

static uint32_t edge_distance(const struct gg_contact_features *c,
                              const struct gg_baseline *b) {
    int32_t d;
    if (!b->have_abs_bounds) {
        d = min32(c->x < 0 ? 0 : c->x, c->y < 0 ? 0 : c->y);
        return d < 0 ? 0u : (uint32_t)d;
    }
    int32_t dx1 = c->x - b->x_min;
    int32_t dx2 = b->x_max - c->x;
    int32_t dy1 = c->y - b->y_min;
    int32_t dy2 = b->y_max - c->y;
    d = min32(min32(dx1, dx2), min32(dy1, dy2));
    return d < 0 ? 0u : (uint32_t)d;
}

struct gg_risk_eval gg_evaluate_risk(const struct gg_contact_features *c,
                                     const struct gg_baseline *b) {
    struct gg_risk_eval r = {0,0,0,0};
    if (!c || !b || !c->have_position) return r;

    if (c->duration_us == 0u) {
        r.score += 35u; r.evidence_mask |= GG_EVID_FAST; r.family_mask |= GG_FAMILY_TIMING;
    } else if (c->duration_us <= 5000u) {
        r.score += 70u; r.evidence_mask |= GG_EVID_FAST; r.family_mask |= GG_FAMILY_TIMING;
    } else if (c->duration_us <= 8000u) {
        r.score += 42u; r.evidence_mask |= GG_EVID_FAST; r.family_mask |= GG_FAMILY_TIMING;
    }

    {
        uint32_t edge = edge_distance(c,b);
        if (edge <= 3u) {
            r.score += 42u; r.evidence_mask |= GG_EVID_EDGE; r.family_mask |= GG_FAMILY_SPATIAL;
        } else if (edge <= 10u) {
            r.score += 16u; r.evidence_mask |= GG_EVID_EDGE; r.family_mask |= GG_FAMILY_SPATIAL;
        }
    }

    if (b->count >= 20u) {
        if (b->avg_duration_us > 0u && c->duration_us > 0u &&
            c->duration_us < b->avg_duration_us / 6u) {
            r.score += 24u;
            r.evidence_mask |= GG_EVID_BASE_SHORT;
            r.family_mask |= GG_FAMILY_TIMING; /* same independent family as FAST */
        }
        if (b->avg_path_px > 0u && c->path_px > b->avg_path_px * 8u &&
            b->avg_duration_us > 0u && c->duration_us < b->avg_duration_us / 2u) {
            r.score += 18u;
            r.evidence_mask |= GG_EVID_PATH_BURST;
            r.family_mask |= GG_FAMILY_MOTION;
        }
        if (c->major >= 0 && b->avg_major >= 2u) {
            uint32_t m = (uint32_t)c->major;
            if (m * 5u < b->avg_major || m > b->avg_major * 5u) {
                r.score += 10u;
                r.evidence_mask |= GG_EVID_MAJOR;
                r.family_mask |= GG_FAMILY_GEOMETRY;
            }
        }
    }

    if (r.score > 100u) r.score = 100u;
    r.family_count = popcount32(r.family_mask);
    return r;
}

int gg_is_suspect(const struct gg_risk_eval *r) {
    return r && r->score >= 65u && r->family_count >= 2u;
}
int gg_would_drop(const struct gg_risk_eval *r) {
    return r && r->score >= 85u && r->family_count >= 2u;
}
