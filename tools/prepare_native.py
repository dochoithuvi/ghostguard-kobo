#!/usr/bin/env python3
from pathlib import Path

p = Path("src/ghostguardd.c")
src = p.read_text()

# Runtime state must never use document-like extensions or Nickel may import it.
for old, new, label in (
    ("/mnt/onboard/.adds/ghostguard/data/profile.txt", "/mnt/onboard/.adds/ghostguard/data/observer_profile.ggdata", "profile path"),
    ("/mnt/onboard/.adds/ghostguard/data/RUNTIME_FAULT.txt", "/mnt/onboard/.adds/ghostguard/data/RUNTIME_FAULT.ggstate", "fault path"),
):
    if old not in src:
        raise SystemExit(f"native private-state anchor missing: {label}")
    src = src.replace(old, new, 1)

# Persist richer metrics for the contact which just ended so Capture can log
# enough context to distinguish controller chatter from legitimate touches.
old_last_decl = 'static int last_end_happened=0,last_end_candidate=0;static u32 last_end_risk=0,last_end_families=0,last_end_sec=0,last_end_usec=0;'
new_last_decl = old_last_decl + 'static s32 last_end_tracking=-1,last_end_sx=-1,last_end_sy=-1,last_end_x=-1,last_end_y=-1;static u32 last_end_path=0;'
if old_last_decl not in src:
    raise SystemExit("native contact telemetry declaration anchor missing")
src = src.replace(old_last_decl, new_last_decl, 1)

old_end_tail = 'last_end_happened=1;last_end_candidate=wd;last_end_risk=rv.score;last_end_families=rv.signals;last_end_sec=sec;last_end_usec=usec;reset_slot(s);'
new_end_tail = 'last_end_happened=1;last_end_candidate=wd;last_end_risk=rv.score;last_end_families=rv.signals;last_end_sec=sec;last_end_usec=usec;last_end_tracking=s->tracking;last_end_sx=s->havepos?s->sx:-1;last_end_sy=s->havepos?s->sy:-1;last_end_x=s->havepos?s->x:-1;last_end_y=s->havepos?s->y:-1;last_end_path=s->path;reset_slot(s);'
if old_end_tail not in src:
    raise SystemExit("native contact telemetry end anchor missing")
src = src.replace(old_end_tail, new_end_tail, 1)

# Status metadata should reflect the normal quarantine used by the proxy.
src = src.replace('QUARANTINE_MS=10\\n', 'QUARANTINE_MS=25\\n', 1)
# After EVIOCGRAB the proxy starts in forwarding-only PRECHECK; classifier blocking
# is enabled later by the supervisor through PROTECT_FILTER_ARMED.
if 'STATE=ACTIVE' not in src:
    raise SystemExit("native active-state anchor missing")
src = src.replace('STATE=ACTIVE', 'STATE=ACTIVE_PRECHECK', 1)

old_release = 'static void release_protect(const char*reason){if(protect_active&&phys_fd>=0)k_ioctl(phys_fd,EVIOCGRAB,0);protect_active=0;write_text(protect_status_path,reason);write_profile();}'
new_release = 'static void release_protect(const char*reason){if(protect_active&&phys_fd>=0)k_ioctl(phys_fd,EVIOCGRAB,0);protect_active=0;protect_requested=0;if(uinput_fd>=0){k_ioctl(uinput_fd,UI_DEV_DESTROY,0);k_close(uinput_fd);uinput_fd=-1;uinput_ready=0;}write_text(protect_status_path,reason);write_profile();}'

old_log = 'static void log_block(u32 sec,u32 usec,u32 risk,u32 fam){char b[160];u32 p=0;p=addu32(b,p,sec,sizeof(b));p=addstr(b,p,".",sizeof(b));p=addu32(b,p,usec,sizeof(b));p=addstr(b,p,",risk=",sizeof(b));p=addu32(b,p,risk,sizeof(b));p=addstr(b,p,",families=",sizeof(b));p=addu32(b,p,fam,sizeof(b));p=addstr(b,p,"\\n",sizeof(b));append_buf(blocked_path,b,p);}'
new_log = old_log + 'static void log_block_burst(u32 sec,u32 usec,u32 risk,u32 fam){char b[192];u32 p=0;p=addu32(b,p,sec,sizeof(b));p=addstr(b,p,".",sizeof(b));p=addu32(b,p,usec,sizeof(b));p=addstr(b,p,",risk=",sizeof(b));p=addu32(b,p,risk,sizeof(b));p=addstr(b,p,",families=",sizeof(b));p=addu32(b,p,fam,sizeof(b));p=addstr(b,p,",reason=BURST\\n",sizeof(b));append_buf(blocked_path,b,p);}static void log_block_episode(u32 sec,u32 usec,u32 risk,u32 fam){char b[208];u32 p=0;p=addu32(b,p,sec,sizeof(b));p=addstr(b,p,".",sizeof(b));p=addu32(b,p,usec,sizeof(b));p=addstr(b,p,",risk=",sizeof(b));p=addu32(b,p,risk,sizeof(b));p=addstr(b,p,",families=",sizeof(b));p=addu32(b,p,fam,sizeof(b));p=addstr(b,p,",reason=EPISODE\\n",sizeof(b));append_buf(blocked_path,b,p);}'

old_q = 'static struct input_event qbuf[QMAX];static u32 qcount=0,qsec=0,qusec=0;static int qactive=0,qpassthrough=0,qmulti=0;'
new_q = '''static struct input_event qbuf[QMAX];static u32 qcount=0,qevents=0,qsec=0,qusec=0;static int qactive=0,qpassthrough=0,qmulti=0,suppress_tail=0;
static u32 burst_hits=0,burst_last_sec=0,burst_last_usec=0;static int burst_guard=0;
static u32 episode_hits=0,episode_multi_hits=0,episode_short_hits=0,episode_last_sec=0,episode_last_usec=0,episode_prev_sec=0,episode_prev_usec=0;static int episode_guard=0,episode_have_prev=0;
static const char *capture_path="/mnt/onboard/.adds/ghostguard/data/ghost_capture.gglog";
static const char *episode_status_path="/mnt/onboard/.adds/ghostguard/data/EPISODE_STATUS.ggstate";
static const char *filter_arm_path="/mnt/onboard/.adds/ghostguard/runtime/PROTECT_FILTER_ARMED";
static const char *proxy_status_path="/mnt/onboard/.adds/ghostguard/data/PROXY_STATUS.ggstate";
static u32 capture_seq=0,proxy_forwarded_frames=0,escape_grace_contacts=0,consecutive_blocks=0;static int filter_active=0;
static void write_proxy_status(const char*state){char b[192];u32 p=0;p=addstr(b,p,"STATE=",sizeof(b));p=addstr(b,p,state,sizeof(b));p=addstr(b,p,"\\nFORWARDED_FRAMES=",sizeof(b));p=addu32(b,p,proxy_forwarded_frames,sizeof(b));p=addstr(b,p,"\\nFILTER_ACTIVE=",sizeof(b));p=addu32(b,p,filter_active?1u:0u,sizeof(b));p=addstr(b,p,"\\nFAIL_OPEN=1\\n",sizeof(b));b[p]=0;write_text(proxy_status_path,b);}
static void episode_state(int on){if(on){if(!episode_guard){episode_guard=1;write_text(episode_status_path,"STATE=ACTIVE\\n");}}else{if(episode_guard){episode_guard=0;write_text(episode_status_path,"STATE=IDLE\\n");}}}
static u32 episode_gap(u32 sec,u32 usec){if(!episode_have_prev)return 0xffffffffu;return timeval_diff_us(episode_prev_sec,episode_prev_usec,sec,usec);}
static void episode_decay(u32 sec,u32 usec){if(!episode_hits&&!episode_guard)return;if(episode_last_sec||episode_last_usec){u32 g=timeval_diff_us(episode_last_sec,episode_last_usec,sec,usec);if(g>1200000u){episode_hits=0;episode_multi_hits=0;episode_short_hits=0;episode_state(0);}}}
static int episode_signature(u32 gap,u32 elapsed,int multi){if(gap==0xffffffffu)return 0;if(multi&&gap<=200000u&&elapsed<=120000u)return 2;if(elapsed<=70000u&&gap<=120000u)return 1;return 0;}
static void episode_note(u32 sec,u32 usec,u32 elapsed,int multi,u32 gap){int sig=episode_signature(gap,elapsed,multi);if(sig){if(episode_hits&&gap<=450000u)episode_hits++;else{episode_hits=1;episode_multi_hits=0;episode_short_hits=0;}if(sig==2)episode_multi_hits++;if(sig==1)episode_short_hits++;episode_last_sec=sec;episode_last_usec=usec;if((episode_multi_hits>=1u&&episode_hits>=2u)||episode_short_hits>=3u)episode_state(1);}else if(episode_hits&&gap>450000u){episode_hits=0;episode_multi_hits=0;episode_short_hits=0;}episode_prev_sec=sec;episode_prev_usec=usec;episode_have_prev=1;}
static int episode_should_drop(u32 elapsed,u32 risk,int multi,u32 gap){if(!episode_guard||elapsed>120000u)return 0;if(risk>=65u)return 1;if(multi&&gap<=250000u)return 1;if(elapsed<=70000u&&gap<=150000u)return 1;return 0;}
static void capture_contact(u32 sec,u32 usec,u32 elapsed,u32 risk,u32 fam,u32 events,int multi,u32 gap,const char*decision){char b[640];u32 p=0;capture_seq++;p=addstr(b,p,"seq=",sizeof(b));p=addu32(b,p,capture_seq,sizeof(b));p=addstr(b,p,",sec=",sizeof(b));p=addu32(b,p,sec,sizeof(b));p=addstr(b,p,",usec=",sizeof(b));p=addu32(b,p,usec,sizeof(b));p=addstr(b,p,",dur_us=",sizeof(b));p=addu32(b,p,elapsed,sizeof(b));p=addstr(b,p,",gap_us=",sizeof(b));p=addu32(b,p,gap,sizeof(b));p=addstr(b,p,",events=",sizeof(b));p=addu32(b,p,events,sizeof(b));p=addstr(b,p,",tracking=",sizeof(b));p=adds32(b,p,last_end_tracking,sizeof(b));p=addstr(b,p,",sx=",sizeof(b));p=adds32(b,p,last_end_sx,sizeof(b));p=addstr(b,p,",sy=",sizeof(b));p=adds32(b,p,last_end_sy,sizeof(b));p=addstr(b,p,",x=",sizeof(b));p=adds32(b,p,last_end_x,sizeof(b));p=addstr(b,p,",y=",sizeof(b));p=adds32(b,p,last_end_y,sizeof(b));p=addstr(b,p,",path=",sizeof(b));p=addu32(b,p,last_end_path,sizeof(b));p=addstr(b,p,",risk=",sizeof(b));p=addu32(b,p,risk,sizeof(b));p=addstr(b,p,",families=",sizeof(b));p=addu32(b,p,fam,sizeof(b));p=addstr(b,p,",multi=",sizeof(b));p=addu32(b,p,multi?1u:0u,sizeof(b));p=addstr(b,p,",burst_hits=",sizeof(b));p=addu32(b,p,burst_hits,sizeof(b));p=addstr(b,p,",burst_guard=",sizeof(b));p=addu32(b,p,burst_guard?1u:0u,sizeof(b));p=addstr(b,p,",episode_hits=",sizeof(b));p=addu32(b,p,episode_hits,sizeof(b));p=addstr(b,p,",episode_guard=",sizeof(b));p=addu32(b,p,episode_guard?1u:0u,sizeof(b));p=addstr(b,p,",filter_active=",sizeof(b));p=addu32(b,p,filter_active?1u:0u,sizeof(b));p=addstr(b,p,",consecutive_blocks=",sizeof(b));p=addu32(b,p,consecutive_blocks,sizeof(b));p=addstr(b,p,",decision=",sizeof(b));p=addstr(b,p,decision,sizeof(b));p=addstr(b,p,"\\n",sizeof(b));append_buf(capture_path,b,p);}
static u32 protect_hold_us(void){if(episode_guard)return 120000u;return burst_guard?80000u:25000u;}
static u32 burst_cut_us(void){u32 c=avg_duration_us? (avg_duration_us>>1):30000u;if(c<18000u)c=18000u;if(c>70000u)c=70000u;return c;}
static void burst_decay(u32 sec,u32 usec){if(!burst_hits)return;{u32 gap=timeval_diff_us(burst_last_sec,burst_last_usec,sec,usec);if(gap>1000000u){burst_hits=0;burst_guard=0;}}}
static int burst_anomaly(u32 elapsed,u32 risk){u32 cut=burst_cut_us();if(elapsed>cut)return 0;if(risk>=35u)return 1;if(avg_duration_us>0u&&elapsed<=cut)return 1;return elapsed<=18000u;}
static void burst_note(u32 sec,u32 usec,u32 elapsed,u32 risk){u32 gap=0xffffffffu;if(burst_hits)gap=timeval_diff_us(burst_last_sec,burst_last_usec,sec,usec);if(burst_anomaly(elapsed,risk)){if(burst_hits&&gap<=450000u)burst_hits++;else burst_hits=1;burst_last_sec=sec;burst_last_usec=usec;if(burst_hits>=3u)burst_guard=1;}else if(burst_hits&&gap>450000u){burst_hits=0;burst_guard=0;}}
static int burst_should_drop(u32 elapsed,u32 risk,u32 families){u32 cut=burst_cut_us();if(!burst_guard||elapsed>80000u)return 0;if(risk<35u)return 0;if(risk>=65u)return 1;if(families>=1u&&elapsed<=cut)return 1;return 0;}'''

old_qreset = 'static void qreset(void){qcount=0;qactive=0;qpassthrough=0;qmulti=0;qsec=qusec=0;}'
new_qreset = 'static void qreset(void){qcount=0;qevents=0;qactive=0;qpassthrough=0;qmulti=0;qsec=qusec=0;}'

old_process = 'static void protect_process(struct input_event*e){if(e->type==EV_SYN&&e->code==SYN_DROPPED){qreset();release_protect("STATE=SYN_DROPPED_FAIL_OPEN\\nPROTECT_ACTIVE=0\\nFAIL_OPEN=1\\n");process(e);return;}maybe_arm_on_frame(e);if(!protect_active){process(e);return;}if(!qactive&&contact_start_event(e)){qactive=1;qsec=(u32)e->tv_sec;qusec=(u32)e->tv_usec;qcount=0;qpassthrough=0;qmulti=0;}if(!qactive){process(e);forward_event(e);return;}if(qpassthrough){process(e);forward_event(e);if(last_end_happened)qreset();return;}if(qcount>=QMAX){qflush();qpassthrough=1;process(e);forward_event(e);return;}qbuf[qcount++]=*e;process(e);if(raw_mt_count>1)qmulti=1;{u32 elapsed=timeval_diff_us(qsec,qusec,(u32)e->tv_sec,(u32)e->tv_usec);if(qmulti){qflush();qpassthrough=1;return;}if(last_end_happened){if(last_end_candidate&&elapsed<=10000u){log_block(last_end_sec,last_end_usec,last_end_risk,last_end_families);qreset();return;}qflush();qreset();return;}if(elapsed>=10000u){qflush();qpassthrough=1;return;}}}'
new_process = '''static void protect_process(struct input_event*e){u32 nowsec=(u32)e->tv_sec,nowusec=(u32)e->tv_usec;if(e->type==EV_SYN&&e->code==SYN_DROPPED){qreset();suppress_tail=0;burst_hits=0;burst_guard=0;episode_hits=0;episode_multi_hits=0;episode_short_hits=0;episode_state(0);filter_active=0;escape_grace_contacts=0;consecutive_blocks=0;release_protect("STATE=SYN_DROPPED_FAIL_OPEN\\nPROTECT_ACTIVE=0\\nFILTER_ACTIVE=0\\nFAIL_OPEN=1\\n");process(e);return;}maybe_arm_on_frame(e);if(!protect_active){process(e);return;}if(filter_active&&!file_exists(filter_arm_path)){qreset();suppress_tail=0;filter_active=0;escape_grace_contacts=0;consecutive_blocks=0;release_protect("STATE=FILTER_DISARMED_FAIL_OPEN\\nPROTECT_ACTIVE=0\\nFILTER_ACTIVE=0\\nFAIL_OPEN=1\\n");process(e);return;}if(!filter_active){if(file_exists(filter_arm_path)){filter_active=1;escape_grace_contacts=3u;consecutive_blocks=0;write_text(protect_status_path,"STATE=ACTIVE\\nPROTECT_ACTIVE=1\\nINPUT_GRAB=EVIOCGRAB\\nFILTER_ACTIVE=1\\nESCAPE_VALVE=1\\nFAIL_OPEN=1\\n");write_proxy_status("FILTER_ARMED");}else{process(e);if(forward_event(e)&&e->type==EV_SYN&&e->code==SYN_REPORT){proxy_forwarded_frames++;write_proxy_status("PRECHECK_FORWARD_OK");}return;}}if(escape_grace_contacts>0u){process(e);if(!forward_event(e))return;if(last_end_happened){escape_grace_contacts--;consecutive_blocks=0;}return;}if(suppress_tail){process(e);if(e->type==EV_SYN&&e->code==SYN_REPORT)suppress_tail=0;return;}if(!qactive&&contact_start_event(e)){burst_decay(nowsec,nowusec);episode_decay(nowsec,nowusec);qactive=1;qsec=nowsec;qusec=nowusec;qcount=0;qevents=0;qpassthrough=0;qmulti=0;}if(!qactive){process(e);forward_event(e);return;}if(qpassthrough){qevents++;process(e);if(raw_mt_count>1)qmulti=1;forward_event(e);if(last_end_happened){u32 elapsed=timeval_diff_us(qsec,qusec,last_end_sec,last_end_usec);u32 gap=episode_gap(last_end_sec,last_end_usec);burst_note(last_end_sec,last_end_usec,elapsed,last_end_risk);episode_note(last_end_sec,last_end_usec,elapsed,qmulti,gap);consecutive_blocks=0;capture_contact(last_end_sec,last_end_usec,elapsed,last_end_risk,last_end_families,qevents,qmulti,gap,"ALLOW_PASSTHROUGH");qreset();}return;}if(qcount>=QMAX){qflush();qpassthrough=1;consecutive_blocks=0;qevents++;process(e);if(raw_mt_count>1)qmulti=1;forward_event(e);return;}qbuf[qcount++]=*e;qevents++;process(e);if(raw_mt_count>1)qmulti=1;{u32 elapsed=timeval_diff_us(qsec,qusec,nowsec,nowusec);u32 hold=protect_hold_us();if(qmulti&&!episode_guard){qflush();qpassthrough=1;consecutive_blocks=0;return;}if(last_end_happened){u32 gap=episode_gap(last_end_sec,last_end_usec);int classic_drop=(last_end_candidate&&elapsed<=hold);int burst_drop=0,episode_drop=0;burst_note(last_end_sec,last_end_usec,elapsed,last_end_risk);episode_note(last_end_sec,last_end_usec,elapsed,qmulti,gap);if(!classic_drop)burst_drop=burst_should_drop(elapsed,last_end_risk,last_end_families);if(!classic_drop&&!burst_drop)episode_drop=episode_should_drop(elapsed,last_end_risk,qmulti,gap);if(classic_drop||burst_drop||episode_drop){if(consecutive_blocks>=2u){consecutive_blocks=0;capture_contact(last_end_sec,last_end_usec,elapsed,last_end_risk,last_end_families,qevents,qmulti,gap,"ALLOW_ESCAPE");qflush();qreset();return;}consecutive_blocks++;if(classic_drop){capture_contact(last_end_sec,last_end_usec,elapsed,last_end_risk,last_end_families,qevents,qmulti,gap,"BLOCK_CLASSIC");log_block(last_end_sec,last_end_usec,last_end_risk,last_end_families);}else if(burst_drop){capture_contact(last_end_sec,last_end_usec,elapsed,last_end_risk,last_end_families,qevents,qmulti,gap,"BLOCK_BURST");log_block_burst(last_end_sec,last_end_usec,last_end_risk,last_end_families);}else{capture_contact(last_end_sec,last_end_usec,elapsed,last_end_risk,last_end_families,qevents,qmulti,gap,"BLOCK_EPISODE");log_block_episode(last_end_sec,last_end_usec,last_end_risk,last_end_families);}qreset();suppress_tail=1;return;}consecutive_blocks=0;capture_contact(last_end_sec,last_end_usec,elapsed,last_end_risk,last_end_families,qevents,qmulti,gap,"ALLOW");qflush();qreset();return;}if(elapsed>=hold){qflush();qpassthrough=1;consecutive_blocks=0;return;}}}'''

for old, new, label in (
    (old_release, new_release, "release"),
    (old_log, new_log, "block log"),
    (old_q, new_q, "adaptive queue + episode capture + safety preflight"),
    (old_qreset, new_qreset, "queue reset"),
    (old_process, new_process, "Safety Handshake Ghost Episode Guard protect_process"),
):
    if old not in src:
        raise SystemExit(f"native hardening anchor missing: {label}")
    src = src.replace(old, new, 1)

out = Path(".build/ghostguardd.c")
out.parent.mkdir(exist_ok=True)
out.write_text(src)
