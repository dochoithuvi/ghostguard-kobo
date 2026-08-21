#ifndef GG_CLASSIFIER_H
#define GG_CLASSIFIER_H

#include <stdint.h>

enum gg_evidence_bits {
    GG_EVID_FAST       = 1u << 0,
    GG_EVID_EDGE       = 1u << 1,
    GG_EVID_BASE_SHORT = 1u << 2,
    GG_EVID_PATH_BURST = 1u << 3,
    GG_EVID_MAJOR      = 1u << 4,
};

enum gg_evidence_family_bits {
    GG_FAMILY_TIMING   = 1u << 0,
    GG_FAMILY_SPATIAL  = 1u << 1,
    GG_FAMILY_MOTION   = 1u << 2,
    GG_FAMILY_GEOMETRY = 1u << 3,
};

struct gg_baseline {
    uint32_t count;
    uint32_t avg_duration_us;
    uint32_t avg_path_px;
    uint32_t avg_major;
    int have_abs_bounds;
    int32_t x_min, x_max, y_min, y_max;
};

struct gg_contact_features {
    int have_position;
    uint32_t duration_us;
    int32_t x, y;
    uint32_t path_px;
    int32_t major;
};

struct gg_risk_eval {
    uint32_t score;
    uint32_t evidence_mask;
    uint32_t family_mask;
    uint32_t family_count;
};

struct gg_risk_eval gg_evaluate_risk(const struct gg_contact_features *c,
                                     const struct gg_baseline *b);
int gg_is_suspect(const struct gg_risk_eval *r);
int gg_would_drop(const struct gg_risk_eval *r);

#endif
