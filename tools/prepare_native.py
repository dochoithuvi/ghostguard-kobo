#!/usr/bin/env python3
from pathlib import Path

p = Path("src/ghostguardd.c")
original = p.read_text()
src = original

old_release = 'static void release_protect(const char*reason){if(protect_active&&phys_fd>=0)k_ioctl(phys_fd,EVIOCGRAB,0);protect_active=0;write_text(protect_status_path,reason);write_profile();}'
new_release = 'static void release_protect(const char*reason){if(protect_active&&phys_fd>=0)k_ioctl(phys_fd,EVIOCGRAB,0);protect_active=0;if(uinput_fd>=0){k_ioctl(uinput_fd,UI_DEV_DESTROY,0);k_close(uinput_fd);uinput_fd=-1;uinput_ready=0;}write_text(protect_status_path,reason);write_profile();}'
old_q = 'static struct input_event qbuf[QMAX];static u32 qcount=0,qsec=0,qusec=0;static int qactive=0,qpassthrough=0,qmulti=0;'
new_q = 'static struct input_event qbuf[QMAX];static u32 qcount=0,qsec=0,qusec=0;static int qactive=0,qpassthrough=0,qmulti=0,suppress_tail=0;'
old_process = 'static void protect_process(struct input_event*e){if(e->type==EV_SYN&&e->code==SYN_DROPPED){qreset();release_protect("STATE=SYN_DROPPED_FAIL_OPEN\\nPROTECT_ACTIVE=0\\nFAIL_OPEN=1\\n");process(e);return;}maybe_arm_on_frame(e);if(!protect_active){process(e);return;}if(!qactive&&contact_start_event(e)){qactive=1;qsec=(u32)e->tv_sec;qusec=(u32)e->tv_usec;qcount=0;qpassthrough=0;qmulti=0;}if(!qactive){process(e);forward_event(e);return;}if(qpassthrough){process(e);forward_event(e);if(last_end_happened)qreset();return;}if(qcount>=QMAX){qflush();qpassthrough=1;process(e);forward_event(e);return;}qbuf[qcount++]=*e;process(e);if(raw_mt_count>1)qmulti=1;{u32 elapsed=timeval_diff_us(qsec,qusec,(u32)e->tv_sec,(u32)e->tv_usec);if(qmulti){qflush();qpassthrough=1;return;}if(last_end_happened){if(last_end_candidate&&elapsed<=10000u){log_block(last_end_sec,last_end_usec,last_end_risk,last_end_families);qreset();return;}qflush();qreset();return;}if(elapsed>=10000u){qflush();qpassthrough=1;return;}}}'
new_process = 'static void protect_process(struct input_event*e){if(e->type==EV_SYN&&e->code==SYN_DROPPED){qreset();suppress_tail=0;release_protect("STATE=SYN_DROPPED_FAIL_OPEN\\nPROTECT_ACTIVE=0\\nFAIL_OPEN=1\\n");process(e);return;}maybe_arm_on_frame(e);if(!protect_active){process(e);return;}if(suppress_tail){process(e);if(e->type==EV_SYN&&e->code==SYN_REPORT)suppress_tail=0;return;}if(!qactive&&contact_start_event(e)){qactive=1;qsec=(u32)e->tv_sec;qusec=(u32)e->tv_usec;qcount=0;qpassthrough=0;qmulti=0;}if(!qactive){process(e);forward_event(e);return;}if(qpassthrough){process(e);forward_event(e);if(last_end_happened)qreset();return;}if(qcount>=QMAX){qflush();qpassthrough=1;process(e);forward_event(e);return;}qbuf[qcount++]=*e;process(e);if(raw_mt_count>1)qmulti=1;{u32 elapsed=timeval_diff_us(qsec,qusec,(u32)e->tv_sec,(u32)e->tv_usec);if(qmulti){qflush();qpassthrough=1;return;}if(last_end_happened){if(last_end_candidate&&elapsed<=10000u){log_block(last_end_sec,last_end_usec,last_end_risk,last_end_families);qreset();suppress_tail=1;return;}qflush();qreset();return;}if(elapsed>=10000u){qflush();qpassthrough=1;return;}}}'

for old, new, label in ((old_release, new_release, "release"), (old_q, new_q, "queue"), (old_process, new_process, "protect_process")):
    if old not in src:
        raise SystemExit(f"native hardening anchor missing: {label}")
    src = src.replace(old, new, 1)

out = Path(".build/ghostguardd.c")
out.parent.mkdir(exist_ok=True)
out.write_text(src)
