#!/usr/bin/env python3
"""Replay the v0.8.6 episode trigger against representative contact cadence.

This intentionally models only the high-confidence episode state machine. It is
not a replacement for the native classifier tests; it protects the safety rule
that ordinary taps/double taps do not arm Episode Guard while the captured Kobo
chatter pattern does.
"""

EPISODE_DECAY_US = 1_200_000
WINDOW_US = 450_000


class Guard:
    def __init__(self):
        self.hits = 0
        self.multi_hits = 0
        self.short_hits = 0
        self.last_sig = None
        self.prev_end = None
        self.active = False

    @staticmethod
    def signature(gap_us, dur_us, multi):
        if gap_us is None:
            return 0
        if multi and gap_us <= 200_000 and dur_us <= 120_000:
            return 2
        if dur_us <= 70_000 and gap_us <= 120_000:
            return 1
        return 0

    def feed(self, end_us, dur_us, multi=False):
        if self.last_sig is not None and end_us - self.last_sig > EPISODE_DECAY_US:
            self.hits = self.multi_hits = self.short_hits = 0
            self.active = False

        gap = None if self.prev_end is None else max(0, end_us - self.prev_end)
        sig = self.signature(gap, dur_us, multi)
        if sig:
            if self.hits and gap is not None and gap <= WINDOW_US:
                self.hits += 1
            else:
                self.hits = 1
                self.multi_hits = self.short_hits = 0
            if sig == 2:
                self.multi_hits += 1
            if sig == 1:
                self.short_hits += 1
            self.last_sig = end_us
            if (self.multi_hits >= 1 and self.hits >= 2) or self.short_hits >= 3:
                self.active = True
        elif self.hits and gap is not None and gap > WINDOW_US:
            self.hits = self.multi_hits = self.short_hits = 0

        self.prev_end = end_us
        return self.active


def replay(rows):
    g = Guard()
    armed_at = []
    for i, row in enumerate(rows):
        if g.feed(*row):
            armed_at.append(i)
    return armed_at


# Normal reading/tapping: includes an isolated short double tap, but no sustained
# chatter and no overlap. Episode Guard must stay idle.
normal = [
    (1_000_000, 150_000, False),
    (3_100_000, 120_000, False),
    (5_000_000, 58_000, False),
    (5_110_000, 62_000, False),
    (7_500_000, 140_000, False),
    (9_700_000, 95_000, False),
]
assert replay(normal) == [], "normal taps must not arm Ghost Episode Guard"

# Captured Kobo chatter fingerprint: rapid short contacts plus overlap/multi.
# Guard should arm only after repeated evidence, not on the first odd contact.
ghost = [
    (1_000_000, 160_000, False),
    (1_090_000, 58_000, False),
    (1_175_000, 57_000, True),
    (1_260_000, 46_000, False),
    (1_350_000, 58_000, True),
]
armed = replay(ghost)
assert armed, "captured ghost cadence must arm Ghost Episode Guard"
assert armed[0] >= 2, "one isolated abnormal contact must never arm the guard"

# Three rapid short contacts without multi are sufficient only after sustained
# repetition, protecting ordinary single/double taps.
short_chatter = [
    (1_000_000, 150_000, False),
    (1_100_000, 60_000, False),
    (1_195_000, 58_000, False),
    (1_285_000, 55_000, False),
]
assert replay(short_chatter), "sustained short-contact chatter must arm guard"

# Episode must decay after a quiet interval.
g = Guard()
for row in ghost:
    g.feed(*row)
assert g.active
g.feed(3_000_000, 150_000, False)
assert not g.active, "episode must fail open after the decay interval"

print("Ghost Episode Guard replay: PASS")
