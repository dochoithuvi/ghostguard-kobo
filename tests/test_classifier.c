#include <assert.h>
#include <stdio.h>
#include "gg_classifier.h"

static struct gg_baseline base(void) {
    struct gg_baseline b = {0};
    b.count=40; b.avg_duration_us=120000; b.avg_path_px=15; b.avg_major=8;
    b.have_abs_bounds=1; b.x_min=0; b.x_max=1079; b.y_min=0; b.y_max=1439;
    return b;
}

int main(void) {
    struct gg_baseline b=base();
    struct gg_contact_features c={1,5000,500,700,5,8};
    struct gg_risk_eval r=gg_evaluate_risk(&c,&b);
    assert((r.evidence_mask & GG_EVID_FAST) != 0);
    assert((r.evidence_mask & GG_EVID_BASE_SHORT) != 0);
    assert(r.score >= 85u);
    assert(r.family_count == 1u); /* FAST + BASE_SHORT are one timing family */
    assert(!gg_would_drop(&r));

    c.x=2; c.y=700;
    r=gg_evaluate_risk(&c,&b);
    assert(r.family_count >= 2u);
    assert(gg_would_drop(&r));

    c.x=1078; c.y=700; c.duration_us=5000;
    r=gg_evaluate_risk(&c,&b);
    assert((r.evidence_mask & GG_EVID_EDGE) != 0); /* right edge */

    c.x=500; c.y=1438;
    r=gg_evaluate_risk(&c,&b);
    assert((r.evidence_mask & GG_EVID_EDGE) != 0); /* bottom edge */

    b.avg_major=1; c.x=500; c.y=700; c.duration_us=50000; c.major=100;
    r=gg_evaluate_risk(&c,&b);
    assert((r.evidence_mask & GG_EVID_MAJOR) == 0); /* adaptive disable */

    puts("classifier tests: OK");
    return 0;
}
