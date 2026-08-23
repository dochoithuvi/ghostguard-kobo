#!/usr/bin/env python3
from pathlib import Path

p = Path("src/ghostguardd.c")
src = p.read_text()

# Runtime state must never use document-like extensions or Nickel may import it
# into My Books while the engine is active.
for old, new, label in (
    ("/mnt/onboard/.adds/ghostguard/data/profile.txt", "/mnt/onboard/.adds/ghostguard/data/observer_profile.ggdata", "profile path"),
    ("/mnt/onboard/.adds/ghostguard/data/RUNTIME_FAULT.txt", "/mnt/onboard/.adds/ghostguard/data/RUNTIME_FAULT.ggstate", "fault path"),
):
    if old not in src:
        raise SystemExit(f"native private-state anchor missing: {label}")
    src = src.replace(old, new, 1)

old_release = 'static void release_protect(const char*reason){if(protect_active&&phys_fd>=0)k_ioctl(phys_fd,EVIOCGRAB,0);protect_active=0;write_text(protect_status_path,reason);write_profile();}'
new_release = 'static void release_protect(const char*reason){if(protect_active&&phys_fd>=0)k_ioctl(phys_fd,EVIOCGRAB,0);protect_active=0;if(uinput_fd>=0){k_ioctl(uinput_fd,UI_DEV_DESTROY,0);k_close(uinput_fd);uinput_fd=-1;uinput_ready=0;}write_text(protect_status_path,reason);write_profile();}'

old_log = 'static void log_block(u32 sec,u32 usec,u32 risk,u32 fam){char b[160];u32 p=0;p=addu32(b,p,sec,sizeof(b));p=addstr(b,p,".",sizeof(b));p=addu32(b,p,usec,sizeof(b));p=addstr(b,p,",risk=",sizeof(b));p=addu32(b,p,risk,sizeof(b));p=addstr(b,p,",families=",sizeof(b));p=addu32(b,p,fam,sizeof(b));p=addstr(b,p,"\\n",sizeof(b));append_buf(blocked_path,b,p);}'
new_log = old_log + 'static void log_block_burst(u32 sec,u32 usec,u32 risk,u32 fam){char b[192];u32 p=0;p=addu32(b,p,sec,sizeof(b));p=addstr(b,p,".",sizeof(b));p=addu32(b,p,usec,sizeof(b));p=addstr(b,p,",risk=",sizeof(b));p=addu32(b,p,risk,sizeof(b));p=addstr(b,p,",families=",sizeof(b));p=addu32(b,p,fam,sizeof(b));p=addstr(b,p,",reason=BURST\\n",sizeof(b));append_buf(blocked_path,b,p);}'

old_q = 'static struct input_event qbuf[QMAX];static u32 qcount=0,qsec=0,qusec=0;static int qactive=0,qpassthrough=0,qmulti=0;'
new_q = '''static struct input_event qbuf[QMAX];static u32 qcount=0,qsec=0,qusec=0;static int qactive=0,qpassthrough=0,qmulti=0,suppress_tail=0;
static u32 burst_hits=0,burst_last_sec=0,burst_last_usec=0;static int burst_guard=0;
static u32 protect_hold_us(void){return burst_guard?80000u:25000u;}
static u32 burst_cut_us(void){u32 c=avg_duration_us? (avg_duration_us>>1):30000u;if(c<18000u)c=18000u;if(c>70000u)c=70000u;return c;}
static void burst_decay(u32 sec,u32 usec){if(!burst_hits)return;{u32 gap=timeval_diff_us(burst_last_sec,burst_last_usec,sec,usec);if(gap>1000000u){burst_hits=0;burst_guard=0;}}}
static int burst_anomaly(u32 elapsed,u32 risk){u32 cut=burst_cut_us();if(elapsed>cut)return 0;if(risk>=35u)return 1;if(avg_duration_us>0u&&elapsed<=cut)return 1;return elapsed<=18000u;}
static void burst_note(u32 sec,u32 usec,u32 elapsed,u32 risk){u32 gap=0xffffffffu;if(burst_hits)gap=timeval_diff_us(burst_last_sec,burst_last_usec,sec,usec);if(burst_anomaly(elapsed,risk)){if(burst_hits&&gap<=450000u)burst_hits++;else burst_hits=1;burst_last_sec=sec;burst_last_usec=usec;if(burst_hits>=3u)burst_guard=1;}else if(burst_hits&&gap>450000u){burst_hits=0;burst_guard=0;}}
static int burst_should_drop(u32 elapsed,u32 risk,u32 families){u32 cut=burst_cut_us();if(!burst_guard||elapsed>80000u)return 0;if(risk>=35u)return 1;if(elapsed<=cut)return 1;if(families>=1u&&elapsed<=40000u)return 1;return 0;}'''

old_process = 'static void protect_process(struct input_event*e){if(e->type==EV_SYN&&e->code==SYN_DROPPED){qreset();release_protect("STATE=SYN_DROPPED_FAIL_OPEN\\nPROTECT_ACTIVE=0\\nFAIL_OPEN=1\\n");process(e);return;}maybe_arm_on_frame(e);if(!protect_active){process(e);return;}if(!qactive&&contact_start_event(e)){qactive=1;qsec=(u32)e->tv_sec;qusec=(u32)e->tv_usec;qcount=0;qpassthrough=0;qmulti=0;}if(!qactive){process(e);forward_event(e);return;}if(qpassthrough){process(e);forward_event(e);if(last_end_happened)qreset();return;}if(qcount>=QMAX){qflush();qpassthrough=1;process(e);forward_event(e);return;}qbuf[qcount++]=*e;process(e);if(raw_mt_count>1)qmulti=1;{u32 elapsed=timeval_diff_us(qsec,qusec,(u32)e->tv_sec,(u32)e->tv_usec);if(qmulti){qflush();qpassthrough=1;return;}if(last_end_happened){if(last_end_candidate&&elapsed<=10000u){log_block(last_end_sec,last_end_usec,last_end_risk,last_end_families);qreset();return;}qflush();qreset();return;}if(elapsed>=10000u){qflush();qpassthrough=1;return;}}}'
new_process = '''static void protect_process(struct input_event*e){u32 nowsec=(u32)e->tv_sec,nowusec=(u32)e->tv_usec;if(e->type==EV_SYN&&e->code==SYN_DROPPED){qreset();suppress_tail=0;burst_hits=0;burst_guard=0;release_protect("STATE=SYN_DROPPED_FAIL_OPEN\\nPROTECT_ACTIVE=0\\nFAIL_OPEN=1\\n");process(e);return;}maybe_arm_on_frame(e);if(!protect_active){process(e);return;}if(suppress_tail){process(e);if(e->type==EV_SYN&&e->code==SYN_REPORT)suppress_tail=0;return;}if(!qactive&&contact_start_event(e)){burst_decay(nowsec,nowusec);qactive=1;qsec=nowsec;qusec=nowusec;qcount=0;qpassthrough=0;qmulti=0;}if(!qactive){process(e);forward_event(e);return;}if(qpassthrough){process(e);forward_event(e);if(last_end_happened){burst_note(last_end_sec,last_end_usec,timeval_diff_us(qsec,qusec,last_end_sec,last_end_usec),last_end_risk);qreset();}return;}if(qcount>=QMAX){qflush();qpassthrough=1;process(e);forward_event(e);return;}qbuf[qcount++]=*e;process(e);if(raw_mt_count>1)qmulti=1;{u32 elapsed=timeval_diff_us(qsec,qusec,nowsec,nowusec);u32 hold=protect_hold_us();if(qmulti){qflush();qpassthrough=1;return;}if(last_end_happened){int classic_drop=(last_end_candidate&&elapsed<=hold);burst_note(last_end_sec,last_end_usec,elapsed,last_end_risk);if(classic_drop){log_block(last_end_sec,last_end_usec,last_end_risk,last_end_families);qreset();suppress_tail=1;return;}if(burst_should_drop(elapsed,last_end_risk,last_end_families)){log_block_burst(last_end_sec,last_end_usec,last_end_risk,last_end_families);qreset();suppress_tail=1;return;}qflush();qreset();return;}if(elapsed>=hold){qflush();qpassthrough=1;return;}}}'''

for old, new, label in (
    (old_release, new_release, "release"),
    (old_log, new_log, "block log"),
    (old_q, new_q, "adaptive queue"),
    (old_process, new_process, "adaptive protect_process"),
):
    if old not in src:
        raise SystemExit(f"native hardening anchor missing: {label}")
    src = src.replace(old, new, 1)

out = Path(".build/ghostguardd.c")
out.parent.mkdir(exist_ok=True)
out.write_text(src)
