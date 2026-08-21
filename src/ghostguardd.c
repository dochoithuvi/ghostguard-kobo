// DCPRO GhostGuard Native Kobo v0.8.3 Protect Beta
// Freestanding Linux evdev observer/proxy for ARMv7/AArch64.
// Protect mode is fail-open: virtual input must be created and explicitly armed
// by the supervisor before EVIOCGRAB is attempted. Process exit releases grab.

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef signed int s32;
typedef unsigned long ulong;
typedef long slong;

#if defined(__aarch64__)
typedef long ktime_t;
struct input_event { ktime_t tv_sec; ktime_t tv_usec; u16 type; u16 code; s32 value; };
static inline long sc1(long n,long a){ register long x8 __asm__("x8")=n; register long x0 __asm__("x0")=a; __asm__ volatile("svc 0":"+r"(x0):"r"(x8):"memory"); return x0; }
static inline long sc3(long n,long a,long b,long c){ register long x8 __asm__("x8")=n; register long x0 __asm__("x0")=a; register long x1 __asm__("x1")=b; register long x2 __asm__("x2")=c; __asm__ volatile("svc 0":"+r"(x0):"r"(x1),"r"(x2),"r"(x8):"memory"); return x0; }
static inline long sc4(long n,long a,long b,long c,long d){ register long x8 __asm__("x8")=n; register long x0 __asm__("x0")=a; register long x1 __asm__("x1")=b; register long x2 __asm__("x2")=c; register long x3 __asm__("x3")=d; __asm__ volatile("svc 0":"+r"(x0):"r"(x1),"r"(x2),"r"(x3),"r"(x8):"memory"); return x0; }
#define SYS_openat 56
#define SYS_close 57
#define SYS_ioctl 29
#define SYS_read 63
#define SYS_write 64
#define SYS_exit 93
static long k_open4(const char *p,int flags,int mode){ return sc4(SYS_openat,-100,(long)p,flags,mode); }
#else
struct input_event { slong tv_sec; slong tv_usec; u16 type; u16 code; s32 value; };
static inline long sc1(long n,long a){ register long r7 __asm__("r7")=n; register long r0 __asm__("r0")=a; __asm__ volatile("svc 0":"+r"(r0):"r"(r7):"memory"); return r0; }
static inline long sc3(long n,long a,long b,long c){ register long r7 __asm__("r7")=n; register long r0 __asm__("r0")=a; register long r1 __asm__("r1")=b; register long r2 __asm__("r2")=c; __asm__ volatile("svc 0":"+r"(r0):"r"(r1),"r"(r2),"r"(r7):"memory"); return r0; }
#define SYS_exit 1
#define SYS_read 3
#define SYS_write 4
#define SYS_open 5
#define SYS_close 6
#define SYS_ioctl 54
static long k_open4(const char *p,int flags,int mode){ return sc3(SYS_open,(long)p,flags,mode); }
#endif

#define O_RDONLY 0
#define O_WRONLY 1
#define O_CREAT 0100
#define O_TRUNC 01000
#define O_APPEND 02000
#define O_NONBLOCK 04000

#define EV_SYN 0
#define EV_KEY 1
#define EV_REL 2
#define EV_ABS 3
#define EV_MSC 4
#define EV_SW 5
#define EV_MAX 0x1f
#define SYN_REPORT 0
#define SYN_MT_REPORT 2
#define SYN_DROPPED 3
#define ABS_X 0
#define ABS_Y 1
#define ABS_MT_SLOT 47
#define ABS_MT_TOUCH_MAJOR 48
#define ABS_MT_POSITION_X 53
#define ABS_MT_POSITION_Y 54
#define ABS_MT_TRACKING_ID 57
#define ABS_MAX 0x3f
#define REL_MAX 0x0f
#define MSC_MAX 0x07
#define SW_MAX 0x10
#define KEY_MAX 0x2ff
#define BTN_TOUCH 330

#define IOC_NRBITS 8
#define IOC_TYPEBITS 8
#define IOC_SIZEBITS 14
#define IOC_NRSHIFT 0
#define IOC_TYPESHIFT (IOC_NRSHIFT+IOC_NRBITS)
#define IOC_SIZESHIFT (IOC_TYPESHIFT+IOC_TYPEBITS)
#define IOC_DIRSHIFT (IOC_SIZESHIFT+IOC_SIZEBITS)
#define IOC_NONE 0u
#define IOC_WRITE 1u
#define IOC_READ 2u
#define IOC(dir,type,nr,size) (((u32)(dir)<<IOC_DIRSHIFT)|((u32)(type)<<IOC_TYPESHIFT)|((u32)(nr)<<IOC_NRSHIFT)|((u32)(size)<<IOC_SIZESHIFT))
#define IO(type,nr) IOC(IOC_NONE,(type),(nr),0)
#define IOW(type,nr,size) IOC(IOC_WRITE,(type),(nr),(size))
#define IOR(type,nr,size) IOC(IOC_READ,(type),(nr),(size))
#define EVIOCGBIT(ev,len) IOC(IOC_READ,'E',0x20+(ev),(len))
#define EVIOCGABS(abs) IOR('E',0x40+(abs),sizeof(struct input_absinfo))
#define EVIOCGID IOR('E',0x02,sizeof(struct input_id))
#define EVIOCGPROP(len) IOC(IOC_READ,'E',0x09,(len))
#define EVIOCGRAB IOW('E',0x90,sizeof(int))
#define UI_DEV_CREATE IO('U',1)
#define UI_DEV_DESTROY IO('U',2)
#define UI_SET_EVBIT IOW('U',100,sizeof(int))
#define UI_SET_KEYBIT IOW('U',101,sizeof(int))
#define UI_SET_RELBIT IOW('U',102,sizeof(int))
#define UI_SET_ABSBIT IOW('U',103,sizeof(int))
#define UI_SET_MSCBIT IOW('U',104,sizeof(int))
#define UI_SET_SWBIT IOW('U',109,sizeof(int))
#define UI_SET_PROPBIT IOW('U',110,sizeof(int))

struct input_id { u16 bustype,vendor,product,version; };
struct input_absinfo { s32 value, minimum, maximum, fuzz, flat, resolution; };
struct uinput_user_dev {
    char name[80];
    struct input_id id;
    u32 ff_effects_max;
    s32 absmax[64];
    s32 absmin[64];
    s32 absfuzz[64];
    s32 absflat[64];
};

static long k_read(int fd,void *b,u32 n){ return sc3(SYS_read,fd,(long)b,n); }
static long k_write(int fd,const void *b,u32 n){ return sc3(SYS_write,fd,(long)b,n); }
static long k_close(int fd){ return sc1(SYS_close,fd); }
static long k_ioctl(int fd,u32 req,long arg){ return sc3(SYS_ioctl,fd,(long)req,arg); }
static void k_exit(int c){ sc1(SYS_exit,c); for(;;){} }

static void zero(void *p,u32 n){ u8 *b=(u8*)p; while(n--)*b++=0; }
static u32 slen(const char *s){ u32 n=0; while(s[n])n++; return n; }
static void copy(char *d,const char*s,u32 cap){ u32 i=0;if(!cap)return;while(s[i]&&i+1<cap){d[i]=s[i];i++;}d[i]=0; }
static int eqprefix(const char*a,const char*b){ u32 i=0;while(b[i]){if(a[i]!=b[i])return 0;i++;}return 1; }
static u32 u32dec(char *o,u32 v){ char t[11];u32 n=0,i;if(v==0){o[0]='0';return 1;}while(v&&n<10){u32 q=(u32)(((unsigned long long)v*0xCCCCCCCDULL)>>35);u32 r=v-q*10;t[n++]=(char)('0'+r);v=q;}for(i=0;i<n;i++)o[i]=t[n-1-i];return n; }
static u32 s32dec(char *o,s32 v){u32 n=0,x;if(v<0){o[n++]='-';x=(u32)(-(v+1))+1;}else x=(u32)v;return n+u32dec(o+n,x);}
static u32 addstr(char*b,u32 p,const char*s,u32 cap){while(*s&&p+1<cap)b[p++]=*s++;return p;}
static u32 addu32(char*b,u32 p,u32 v,u32 cap){char t[12];u32 n=u32dec(t,v),i;for(i=0;i<n&&p+1<cap;i++)b[p++]=t[i];return p;}
static u32 adds32(char*b,u32 p,s32 v,u32 cap){char t[13];u32 n=s32dec(t,v),i;for(i=0;i<n&&p+1<cap;i++)b[p++]=t[i];return p;}
static void write_text(const char*path,const char*txt){long fd=k_open4(path,O_WRONLY|O_CREAT|O_TRUNC,0644);if(fd>=0){k_write((int)fd,txt,slen(txt));k_close((int)fd);}}
static void append_buf(const char*path,const char*b,u32 n){long fd=k_open4(path,O_WRONLY|O_CREAT|O_APPEND,0644);if(fd>=0){k_write((int)fd,b,n);k_close((int)fd);}}
static int read_small(const char*path,char*b,u32 cap){long fd=k_open4(path,O_RDONLY,0);if(fd<0)return 0;long n=k_read((int)fd,b,cap-1);k_close((int)fd);if(n<=0)return 0;b[n]=0;return (int)n;}
static int file_exists(const char*path){long fd=k_open4(path,O_RDONLY,0);if(fd<0)return 0;k_close((int)fd);return 1;}
static int bit_test(const u8*b,u32 bit){return (b[bit>>3]>>(bit&7u))&1u;}
static u32 abs32(s32 a,s32 b){return (u32)(a>b?a-b:b-a);}
static u32 udiv32(u32 n,u32 d){u32 q=0,r=0;int i;if(!d)return 0;for(i=31;i>=0;i--){r=(r<<1)|((n>>(u32)i)&1u);if(r>=d){r-=d;q|=(1u<<(u32)i);}}return q;}
static u32 timeval_diff_us(u32 s0,u32 u0,u32 s1,u32 u1){u32 ds=s1-s0;if(u1>=u0)return ds*1000000u+(u1-u0);if(ds==0)return 0;return (ds-1u)*1000000u+(1000000u+u1-u0);}

struct slot {int active;s32 tracking;s32 x,y,sx,sy,px,py,major,minmajor,maxmajor;u32 sec,usec,startsec,startusec,path;int havex,havey,havepos;};
static struct slot slots[16];
static int cur_slot=0,btn_down=0,btn_seen=0;
static int raw_mt_slot=0,raw_mt_active[16],raw_mt_count=0;
static u32 contacts=0,suspects=0,would_drop=0,frames=0,raw_events=0;
static u32 baseline_count=0,avg_duration_us=0,avg_path_px=0,avg_major=0;
static u32 risk_low=0,risk_medium=0,risk_high=0,risk_max=0;
static u32 incomplete_contacts=0,no_position_contacts=0,max_risk_signals=0;
static s32 xmin=2147483647,xmax=-2147483647,ymin=2147483647,ymax=-2147483647;
static char mode[16]="LEARN";
static int phys_fd=-1,uinput_fd=-1,protect_requested=0,protect_active=0,uinput_ready=0;
static s32 phys_xmin=0,phys_xmax=0,phys_ymin=0,phys_ymax=0; static int phys_bounds=0;
static const char *contacts_path="/mnt/onboard/.adds/ghostguard/data/contacts.csv";
static const char *blocked_path="/mnt/onboard/.adds/ghostguard/data/blocked.gglog";
static const char *profile_path="/mnt/onboard/.adds/ghostguard/data/profile.txt";
static const char *status_path="/mnt/onboard/.adds/ghostguard/data/status.ggstate";
static const char *fault_path="/mnt/onboard/.adds/ghostguard/data/RUNTIME_FAULT.txt";
static const char *protect_status_path="/mnt/onboard/.adds/ghostguard/data/PROTECT_STATUS.ggstate";
static const char *arm_path="/mnt/onboard/.adds/ghostguard/runtime/PROTECT_ARMED";

#define EVID_FAST 1u
#define EVID_EDGE 2u
#define EVID_BASE_SHORT 4u
#define EVID_PATH_BURST 8u
#define EVID_MAJOR 16u
#define FAMILY_TIMING 1u
#define FAMILY_SPATIAL 2u
#define FAMILY_MOTION 4u
#define FAMILY_GEOM 8u
struct risk_eval {u32 score;u32 signals;u32 mask;u32 families;};
static int last_end_happened=0,last_end_candidate=0;static u32 last_end_risk=0,last_end_families=0,last_end_sec=0,last_end_usec=0;

static u32 find_u32(const char *b,const char *key,u32 def){u32 i=0,k=slen(key);while(b[i]){if((i==0||b[i-1]=='\n')){u32 j=0;while(j<k&&b[i+j]==key[j])j++;if(j==k&&b[i+j]=='='){u32 v=0;j=i+k+1;while(b[j]>='0'&&b[j]<='9'){v=v*10u+(u32)(b[j]-'0');j++;}return v;}}i++;}return def;}
static s32 find_s32(const char*b,const char*key,s32 def){u32 i=0,k=slen(key);while(b[i]){if((i==0||b[i-1]=='\n')){u32 j=0;while(j<k&&b[i+j]==key[j])j++;if(j==k&&b[i+j]=='='){int neg=0;s32 v=0;j=i+k+1;if(b[j]=='-'){neg=1;j++;}while(b[j]>='0'&&b[j]<='9'){v=v*10+(b[j]-'0');j++;}return neg?-v:v;}}i++;}return def;}
static void load_profile(void){char b[2048];int isv=0;if(!read_small(profile_path,b,sizeof(b)))return;isv=eqprefix(b,"DCPRO_GHOSTGUARD_NATIVE_PROFILE_V4")||eqprefix(b,"DCPRO_GHOSTGUARD_NATIVE_PROFILE_V3");if(!isv)return;xmin=find_s32(b,"X_MIN",xmin);xmax=find_s32(b,"X_MAX",xmax);ymin=find_s32(b,"Y_MIN",ymin);ymax=find_s32(b,"Y_MAX",ymax);baseline_count=find_u32(b,"BASELINE_COUNT",0);avg_duration_us=find_u32(b,"AVG_DURATION_US",0);avg_path_px=find_u32(b,"AVG_PATH_PX",0);avg_major=find_u32(b,"AVG_TOUCH_MAJOR",0);if(eqprefix(b,"DCPRO_GHOSTGUARD_NATIVE_PROFILE_V4")){contacts=find_u32(b,"CONTACTS",0);suspects=find_u32(b,"SUSPECTS",0);would_drop=find_u32(b,"WOULD_DROP",0);frames=find_u32(b,"FRAMES",0);raw_events=find_u32(b,"RAW_EVENTS",0);risk_low=find_u32(b,"RISK_LOW",0);risk_medium=find_u32(b,"RISK_MEDIUM",0);risk_high=find_u32(b,"RISK_HIGH",0);risk_max=find_u32(b,"RISK_MAX",0);incomplete_contacts=find_u32(b,"INCOMPLETE_CONTACTS",0);no_position_contacts=find_u32(b,"NO_POSITION_CONTACTS",0);max_risk_signals=find_u32(b,"MAX_RISK_SIGNALS",0);}}
static u32 dur_us(struct slot*s,u32 sec,u32 usec){return timeval_diff_us(s->startsec,s->startusec,sec,usec);}
static void reset_slot(struct slot*s){s->active=0;s->tracking=-1;s->x=s->y=s->sx=s->sy=s->px=s->py=0;s->major=-1;s->minmajor=-1;s->maxmajor=-1;s->path=0;s->havex=s->havey=s->havepos=0;s->sec=s->usec=s->startsec=s->startusec=0;}
static void start_slot(struct slot*s,s32 tracking,u32 sec,u32 usec){reset_slot(s);s->active=1;s->tracking=tracking;s->startsec=sec;s->startusec=usec;s->sec=sec;s->usec=usec;}
static u32 family_count(u32 f){u32 n=0;while(f){n+=f&1u;f>>=1;}return n;}
static struct risk_eval evaluate_risk(struct slot*s,u32 d){struct risk_eval r;r.score=0;r.signals=0;r.mask=0;r.families=0;if(!s->havepos)return r;if(d==0u){r.score+=35;r.mask|=EVID_FAST;r.families|=FAMILY_TIMING;}else if(d<=5000u){r.score+=70;r.mask|=EVID_FAST;r.families|=FAMILY_TIMING;}else if(d<=8000u){r.score+=42;r.mask|=EVID_FAST;r.families|=FAMILY_TIMING;}
    {u32 ed=0xffffffffu;if(phys_bounds){u32 a=abs32(s->x,phys_xmin),b=abs32(s->x,phys_xmax),c=abs32(s->y,phys_ymin),d2=abs32(s->y,phys_ymax);ed=a;if(b<ed)ed=b;if(c<ed)ed=c;if(d2<ed)ed=d2;}else{u32 a=(s->x<0)?0xffffffffu:(u32)s->x,b=(s->y<0)?0xffffffffu:(u32)s->y;ed=a<b?a:b;}if(ed<=3u){r.score+=42;r.mask|=EVID_EDGE;r.families|=FAMILY_SPATIAL;}else if(ed<=10u){r.score+=16;r.mask|=EVID_EDGE;r.families|=FAMILY_SPATIAL;}}
    if(baseline_count>=20u){if(avg_duration_us>0u&&d>0u&&d<udiv32(avg_duration_us,6u)){r.score+=24;r.mask|=EVID_BASE_SHORT;r.families|=FAMILY_TIMING;}if(avg_path_px>0u&&s->path>avg_path_px*8u&&avg_duration_us>0u&&d<(avg_duration_us>>1)){r.score+=18;r.mask|=EVID_PATH_BURST;r.families|=FAMILY_MOTION;}if(s->major>=0&&avg_major>=2u){u32 mm=(u32)s->major;if(mm*5u<avg_major||mm>avg_major*5u){r.score+=10;r.mask|=EVID_MAJOR;r.families|=FAMILY_GEOM;}}}
    if(r.score>100u)r.score=100u;r.signals=family_count(r.families);return r;}
static void update_avg(u32*avg,u32 n,u32 v){u32 sum;if(n<=1){*avg=v;return;}if(n<=64){sum=(*avg)*(n-1u)+v;*avg=udiv32(sum,n);return;}*avg=(((*avg)*31u)+v)>>5;}
static void learn_baseline(struct slot*s,u32 d,u32 risk){u32 n;if(eqprefix(mode,"SHADOW")||eqprefix(mode,"PROTECT"))return;if(risk>=35u||!s->havepos||d<8000u)return;baseline_count++;n=baseline_count;update_avg(&avg_duration_us,n,d);update_avg(&avg_path_px,n,s->path);if(s->major>=0)update_avg(&avg_major,n,(u32)s->major);}
static const char*risk_class(u32 r,u32 sig){if(r>=65u&&sig>=2u)return "SUSPECT";if(r>=35u)return "WATCH";return "NORMAL";}
static const char*end_name(int reason){if(reason==1)return "BTN_TOUCH_UP";if(reason==2)return "TRACKING_END";if(reason==3)return "SESSION_FLUSH";return "UNKNOWN";}

static void write_profile(void){char b[2300];u32 p=0;p=addstr(b,p,"DCPRO_GHOSTGUARD_NATIVE_PROFILE_V4\nMODE=",sizeof(b));p=addstr(b,p,mode,sizeof(b));p=addstr(b,p,"\nCONTACTS=",sizeof(b));p=addu32(b,p,contacts,sizeof(b));p=addstr(b,p,"\nSUSPECTS=",sizeof(b));p=addu32(b,p,suspects,sizeof(b));p=addstr(b,p,"\nWOULD_DROP=",sizeof(b));p=addu32(b,p,would_drop,sizeof(b));p=addstr(b,p,"\nINCOMPLETE_CONTACTS=",sizeof(b));p=addu32(b,p,incomplete_contacts,sizeof(b));p=addstr(b,p,"\nNO_POSITION_CONTACTS=",sizeof(b));p=addu32(b,p,no_position_contacts,sizeof(b));p=addstr(b,p,"\nMAX_RISK_SIGNALS=",sizeof(b));p=addu32(b,p,max_risk_signals,sizeof(b));p=addstr(b,p,"\nRISK_LOW=",sizeof(b));p=addu32(b,p,risk_low,sizeof(b));p=addstr(b,p,"\nRISK_MEDIUM=",sizeof(b));p=addu32(b,p,risk_medium,sizeof(b));p=addstr(b,p,"\nRISK_HIGH=",sizeof(b));p=addu32(b,p,risk_high,sizeof(b));p=addstr(b,p,"\nRISK_MAX=",sizeof(b));p=addu32(b,p,risk_max,sizeof(b));p=addstr(b,p,"\nBASELINE_COUNT=",sizeof(b));p=addu32(b,p,baseline_count,sizeof(b));p=addstr(b,p,"\nAVG_DURATION_US=",sizeof(b));p=addu32(b,p,avg_duration_us,sizeof(b));p=addstr(b,p,"\nAVG_PATH_PX=",sizeof(b));p=addu32(b,p,avg_path_px,sizeof(b));p=addstr(b,p,"\nAVG_TOUCH_MAJOR=",sizeof(b));p=addu32(b,p,avg_major,sizeof(b));p=addstr(b,p,"\nFRAMES=",sizeof(b));p=addu32(b,p,frames,sizeof(b));p=addstr(b,p,"\nRAW_EVENTS=",sizeof(b));p=addu32(b,p,raw_events,sizeof(b));if(contacts){p=addstr(b,p,"\nX_MIN=",sizeof(b));p=adds32(b,p,xmin,sizeof(b));p=addstr(b,p,"\nX_MAX=",sizeof(b));p=adds32(b,p,xmax,sizeof(b));p=addstr(b,p,"\nY_MIN=",sizeof(b));p=adds32(b,p,ymin,sizeof(b));p=addstr(b,p,"\nY_MAX=",sizeof(b));p=adds32(b,p,ymax,sizeof(b));}p=addstr(b,p,"\nPROTECT_ACTIVE=",sizeof(b));p=addstr(b,p,protect_active?"1":"0",sizeof(b));p=addstr(b,p,"\nINPUT_GRAB=",sizeof(b));p=addstr(b,p,protect_active?"EVIOCGRAB":"OFF",sizeof(b));p=addstr(b,p,"\nFAIL_OPEN=1\n",sizeof(b));b[p]=0;write_text(profile_path,b);write_text(status_path,b);}
static void log_contact(struct slot*s,u32 sec,u32 usec,int reason,u32 d,struct risk_eval rv,int incomplete,int wd){char b[760];u32 p=0;p=addu32(b,p,sec,sizeof(b));p=addstr(b,p,".",sizeof(b));p=addu32(b,p,usec,sizeof(b));p=addstr(b,p,",",sizeof(b));p=adds32(b,p,s->tracking,sizeof(b));p=addstr(b,p,",",sizeof(b));p=adds32(b,p,s->havepos?s->x:-1,sizeof(b));p=addstr(b,p,",",sizeof(b));p=adds32(b,p,s->havepos?s->y:-1,sizeof(b));p=addstr(b,p,",",sizeof(b));p=addu32(b,p,d,sizeof(b));p=addstr(b,p,",",sizeof(b));p=adds32(b,p,s->minmajor,sizeof(b));p=addstr(b,p,",",sizeof(b));p=addu32(b,p,s->path,sizeof(b));p=addstr(b,p,",",sizeof(b));p=addu32(b,p,rv.score,sizeof(b));p=addstr(b,p,",",sizeof(b));p=addu32(b,p,rv.signals,sizeof(b));p=addstr(b,p,",",sizeof(b));p=addu32(b,p,rv.mask,sizeof(b));if(incomplete)p=addstr(b,p,",INCOMPLETE,IGNORE,",sizeof(b));else{p=addstr(b,p,",",sizeof(b));p=addstr(b,p,risk_class(rv.score,rv.signals),sizeof(b));p=addstr(b,p,wd?",WOULD_DROP,":",ALLOW,",sizeof(b));}p=addstr(b,p,end_name(reason),sizeof(b));p=addstr(b,p,"\n",sizeof(b));append_buf(contacts_path,b,p);}
static void end_slot(struct slot*s,u32 sec,u32 usec,int reason){if(!s->active)return;u32 d=dur_us(s,sec,usec);struct risk_eval rv=evaluate_risk(s,d);int incomplete=!s->havepos;int sus=(!incomplete&&rv.score>=65u&&rv.signals>=2u);int wd=(!incomplete&&rv.score>=85u&&rv.signals>=2u);contacts++;if(incomplete){incomplete_contacts++;no_position_contacts++;}else{if(sus)suspects++;if(wd)would_drop++;if(rv.score<35)risk_low++;else if(rv.score<65)risk_medium++;else risk_high++;if(rv.score>risk_max)risk_max=rv.score;if(rv.signals>max_risk_signals)max_risk_signals=rv.signals;if(s->x<xmin)xmin=s->x;if(s->x>xmax)xmax=s->x;if(s->y<ymin)ymin=s->y;if(s->y>ymax)ymax=s->y;learn_baseline(s,d,rv.score);}log_contact(s,sec,usec,reason,d,rv,incomplete,wd);last_end_happened=1;last_end_candidate=wd;last_end_risk=rv.score;last_end_families=rv.signals;last_end_sec=sec;last_end_usec=usec;reset_slot(s);if((contacts%20u)==0)write_profile();}
static void update_pos(struct slot*s,int isx,s32 v,u32 sec,u32 usec){s->sec=sec;s->usec=usec;if(isx){if(s->havex&&s->havey)s->path+=abs32(s->px,v);s->x=v;s->px=v;if(!s->havex)s->sx=v;s->havex=1;}else{if(s->havey&&s->havex)s->path+=abs32(s->py,v);s->y=v;s->py=v;if(!s->havey)s->sy=v;s->havey=1;}s->havepos=s->havex&&s->havey;}

static void raw_mt_update(struct input_event*e){if(e->type!=EV_ABS)return;if(e->code==ABS_MT_SLOT){raw_mt_slot=e->value;if(raw_mt_slot<0)raw_mt_slot=0;if(raw_mt_slot>15)raw_mt_slot=15;return;}if(e->code==ABS_MT_TRACKING_ID){if(e->value>=0){if(!raw_mt_active[raw_mt_slot]){raw_mt_active[raw_mt_slot]=1;raw_mt_count++;}}else{if(raw_mt_active[raw_mt_slot]){raw_mt_active[raw_mt_slot]=0;if(raw_mt_count>0)raw_mt_count--;}}}}
static void process(struct input_event*e){u32 sec=(u32)e->tv_sec,usec=(u32)e->tv_usec;raw_events++;last_end_happened=0;raw_mt_update(e);if(e->type==EV_KEY&&e->code==BTN_TOUCH){btn_seen=1;if(e->value){btn_down=1;if(!slots[0].active)start_slot(&slots[0],1000000,sec,usec);}else{btn_down=0;if(slots[0].active)end_slot(&slots[0],sec,usec,1);{int i;for(i=1;i<16;i++)if(slots[i].active)reset_slot(&slots[i]);}}return;}if(e->type==EV_ABS){if(e->code==ABS_MT_SLOT){cur_slot=e->value;if(cur_slot<0)cur_slot=0;if(cur_slot>15)cur_slot=15;return;}if(btn_seen){struct slot*s=&slots[0];if(e->code==ABS_MT_TRACKING_ID){if(e->value>=0&&s->tracking==1000000)s->tracking=e->value;return;}if((e->code==ABS_MT_POSITION_X||e->code==ABS_MT_POSITION_Y||e->code==ABS_X||e->code==ABS_Y)&&btn_down&&!s->active)start_slot(s,1000000,sec,usec);if(!s->active)return;if(e->code==ABS_MT_POSITION_X||e->code==ABS_X)update_pos(s,1,e->value,sec,usec);else if(e->code==ABS_MT_POSITION_Y||e->code==ABS_Y)update_pos(s,0,e->value,sec,usec);else if(e->code==ABS_MT_TOUCH_MAJOR){s->major=e->value;if(s->minmajor<0||e->value<s->minmajor)s->minmajor=e->value;if(s->maxmajor<0||e->value>s->maxmajor)s->maxmajor=e->value;}return;}else{struct slot*s=&slots[cur_slot];if(e->code==ABS_MT_TRACKING_ID){if(e->value<0)end_slot(s,sec,usec,2);else if(!s->active||s->tracking!=e->value)start_slot(s,e->value,sec,usec);return;}if((e->code==ABS_MT_POSITION_X||e->code==ABS_MT_POSITION_Y)&&!s->active)start_slot(s,1000000+cur_slot,sec,usec);if(!s->active)return;if(e->code==ABS_MT_POSITION_X)update_pos(s,1,e->value,sec,usec);else if(e->code==ABS_MT_POSITION_Y)update_pos(s,0,e->value,sec,usec);else if(e->code==ABS_MT_TOUCH_MAJOR){s->major=e->value;if(s->minmajor<0||e->value<s->minmajor)s->minmajor=e->value;if(s->maxmajor<0||e->value>s->maxmajor)s->maxmajor=e->value;}return;}}if(e->type==EV_SYN&&e->code==SYN_REPORT){frames++;if((frames%200u)==0)write_profile();}}

static void detect_bounds(void){struct input_absinfo a,b;zero(&a,sizeof(a));zero(&b,sizeof(b));if(k_ioctl(phys_fd,EVIOCGABS(ABS_MT_POSITION_X),(long)&a)>=0&&k_ioctl(phys_fd,EVIOCGABS(ABS_MT_POSITION_Y),(long)&b)>=0&&a.maximum>a.minimum&&b.maximum>b.minimum){phys_xmin=a.minimum;phys_xmax=a.maximum;phys_ymin=b.minimum;phys_ymax=b.maximum;phys_bounds=1;return;}if(k_ioctl(phys_fd,EVIOCGABS(ABS_X),(long)&a)>=0&&k_ioctl(phys_fd,EVIOCGABS(ABS_Y),(long)&b)>=0&&a.maximum>a.minimum&&b.maximum>b.minimum){phys_xmin=a.minimum;phys_xmax=a.maximum;phys_ymin=b.minimum;phys_ymax=b.maximum;phys_bounds=1;}}
static int set_bits_from(int ufd,int pfd,u32 ev,u32 max,u32 ui_req){u8 bits[128];u32 bytes=(max+8u)/8u,i;zero(bits,sizeof(bits));if(bytes>sizeof(bits))bytes=sizeof(bits);if(k_ioctl(pfd,EVIOCGBIT(ev,bytes),(long)bits)<0)return 0;for(i=0;i<=max;i++)if(bit_test(bits,i))k_ioctl(ufd,ui_req,(long)i);return 1;}
static int setup_uinput(void){long fd=k_open4("/dev/uinput",O_WRONLY|O_NONBLOCK,0);if(fd<0)fd=k_open4("/dev/input/uinput",O_WRONLY|O_NONBLOCK,0);if(fd<0){write_text(protect_status_path,"STATE=UINPUT_UNAVAILABLE\nPROTECT_ACTIVE=0\nFAIL_OPEN=1\n");return 0;}uinput_fd=(int)fd;u8 evbits[8],propbits[16];zero(evbits,sizeof(evbits));zero(propbits,sizeof(propbits));k_ioctl(uinput_fd,UI_SET_EVBIT,EV_SYN);if(k_ioctl(phys_fd,EVIOCGBIT(0,sizeof(evbits)),(long)evbits)>=0){u32 t;for(t=1;t<=EV_MAX;t++)if(bit_test(evbits,t))k_ioctl(uinput_fd,UI_SET_EVBIT,t);}set_bits_from(uinput_fd,phys_fd,EV_KEY,KEY_MAX,UI_SET_KEYBIT);set_bits_from(uinput_fd,phys_fd,EV_REL,REL_MAX,UI_SET_RELBIT);set_bits_from(uinput_fd,phys_fd,EV_ABS,ABS_MAX,UI_SET_ABSBIT);set_bits_from(uinput_fd,phys_fd,EV_MSC,MSC_MAX,UI_SET_MSCBIT);set_bits_from(uinput_fd,phys_fd,EV_SW,SW_MAX,UI_SET_SWBIT);if(k_ioctl(phys_fd,EVIOCGPROP(sizeof(propbits)),(long)propbits)>=0){u32 i;for(i=0;i<sizeof(propbits)*8u;i++)if(bit_test(propbits,i))k_ioctl(uinput_fd,UI_SET_PROPBIT,(long)i);}struct uinput_user_dev u;zero(&u,sizeof(u));copy(u.name,"DCPRO GhostGuard Virtual Touch",sizeof(u.name));k_ioctl(phys_fd,EVIOCGID,(long)&u.id);{u32 i;for(i=0;i<=ABS_MAX;i++){struct input_absinfo ai;zero(&ai,sizeof(ai));if(k_ioctl(phys_fd,EVIOCGABS(i),(long)&ai)>=0){u.absmin[i]=ai.minimum;u.absmax[i]=ai.maximum;u.absfuzz[i]=ai.fuzz;u.absflat[i]=ai.flat;}}}if(k_write(uinput_fd,&u,sizeof(u))!=(long)sizeof(u)){write_text(protect_status_path,"STATE=UINPUT_CONFIG_WRITE_FAILED\nPROTECT_ACTIVE=0\nFAIL_OPEN=1\n");k_close(uinput_fd);uinput_fd=-1;return 0;}if(k_ioctl(uinput_fd,UI_DEV_CREATE,0)<0){write_text(protect_status_path,"STATE=UINPUT_CREATE_FAILED\nPROTECT_ACTIVE=0\nFAIL_OPEN=1\n");k_close(uinput_fd);uinput_fd=-1;return 0;}uinput_ready=1;write_text(protect_status_path,"STATE=VIRTUAL_READY_WAITING_FOR_NICKEL\nPROTECT_ACTIVE=0\nFAIL_OPEN=1\n");return 1;}
static void release_protect(const char*reason){if(protect_active&&phys_fd>=0)k_ioctl(phys_fd,EVIOCGRAB,0);protect_active=0;write_text(protect_status_path,reason);write_profile();}
static int forward_event(struct input_event*e){if(uinput_fd<0)return 0;if(k_write(uinput_fd,e,sizeof(*e))!=(long)sizeof(*e)){release_protect("STATE=UINPUT_WRITE_FAILED_FAIL_OPEN\nPROTECT_ACTIVE=0\nFAIL_OPEN=1\n");return 0;}return 1;}
static void log_block(u32 sec,u32 usec,u32 risk,u32 fam){char b[160];u32 p=0;p=addu32(b,p,sec,sizeof(b));p=addstr(b,p,".",sizeof(b));p=addu32(b,p,usec,sizeof(b));p=addstr(b,p,",risk=",sizeof(b));p=addu32(b,p,risk,sizeof(b));p=addstr(b,p,",families=",sizeof(b));p=addu32(b,p,fam,sizeof(b));p=addstr(b,p,"\n",sizeof(b));append_buf(blocked_path,b,p);}

#define QMAX 256
static struct input_event qbuf[QMAX];static u32 qcount=0,qsec=0,qusec=0;static int qactive=0,qpassthrough=0,qmulti=0;
static void qreset(void){qcount=0;qactive=0;qpassthrough=0;qmulti=0;qsec=qusec=0;}
static void qflush(void){u32 i;for(i=0;i<qcount;i++){if(!protect_active)break;if(!forward_event(&qbuf[i]))break;}qcount=0;}
static int contact_start_event(struct input_event*e){if(e->type==EV_KEY&&e->code==BTN_TOUCH&&e->value)return 1;if(e->type==EV_ABS&&e->code==ABS_MT_TRACKING_ID&&e->value>=0)return 1;return 0;}
static void maybe_arm_on_frame(struct input_event*e){if(!protect_requested||protect_active||!uinput_ready)return;if(e->type!=EV_SYN||e->code!=SYN_REPORT)return;if(!file_exists(arm_path))return;if(k_ioctl(phys_fd,EVIOCGRAB,1)>=0){protect_active=1;qreset();write_text(protect_status_path,"STATE=ACTIVE\nPROTECT_ACTIVE=1\nINPUT_GRAB=EVIOCGRAB\nQUARANTINE_MS=10\nFAIL_OPEN=1\n");write_profile();}else write_text(protect_status_path,"STATE=EVIOCGRAB_FAILED\nPROTECT_ACTIVE=0\nFAIL_OPEN=1\n");}
static void protect_process(struct input_event*e){if(e->type==EV_SYN&&e->code==SYN_DROPPED){qreset();release_protect("STATE=SYN_DROPPED_FAIL_OPEN\nPROTECT_ACTIVE=0\nFAIL_OPEN=1\n");process(e);return;}maybe_arm_on_frame(e);if(!protect_active){process(e);return;}if(!qactive&&contact_start_event(e)){qactive=1;qsec=(u32)e->tv_sec;qusec=(u32)e->tv_usec;qcount=0;qpassthrough=0;qmulti=0;}if(!qactive){process(e);forward_event(e);return;}if(qpassthrough){process(e);forward_event(e);if(last_end_happened)qreset();return;}if(qcount>=QMAX){qflush();qpassthrough=1;process(e);forward_event(e);return;}qbuf[qcount++]=*e;process(e);if(raw_mt_count>1)qmulti=1;{u32 elapsed=timeval_diff_us(qsec,qusec,(u32)e->tv_sec,(u32)e->tv_usec);if(qmulti){qflush();qpassthrough=1;return;}if(last_end_happened){if(last_end_candidate&&elapsed<=10000u){log_block(last_end_sec,last_end_usec,last_end_risk,last_end_families);qreset();return;}qflush();qreset();return;}if(elapsed>=10000u){qflush();qpassthrough=1;return;}}}

static void run(void){int i;for(i=0;i<16;i++){reset_slot(&slots[i]);raw_mt_active[i]=0;}load_profile();char m[32];if(read_small("/mnt/onboard/.adds/ghostguard/runtime/mode",m,sizeof(m))){if(eqprefix(m,"PROTECT")){copy(mode,"PROTECT",sizeof(mode));protect_requested=1;}else if(eqprefix(m,"SHADOW"))copy(mode,"SHADOW",sizeof(mode));}char dev[128];int n=read_small("/mnt/onboard/.adds/ghostguard/runtime/input_device",dev,sizeof(dev));if(!n){write_text(fault_path,"INPUT_DEVICE_FILE_MISSING\n");k_exit(2);}for(i=0;i<n;i++){if(dev[i]=='\n'||dev[i]=='\r'){dev[i]=0;break;}}long fd=k_open4(dev,O_RDONLY,0);if(fd<0){write_text(fault_path,"INPUT_DEVICE_OPEN_FAILED\n");k_exit(3);}phys_fd=(int)fd;detect_bounds();char existing[2];if(!read_small(contacts_path,existing,sizeof(existing))){const char*h="timestamp,tracking_id,x,y,duration_us,touch_major,path_px,risk_score,risk_signals,evidence_mask,class,shadow_action,end_type\n";append_buf(contacts_path,h,slen(h));}if(protect_requested)setup_uinput();write_profile();struct input_event e;for(;;){long r=k_read(phys_fd,&e,sizeof(e));if(r==(long)sizeof(e)){if(protect_requested)protect_process(&e);else process(&e);}else if(r<0){release_protect("STATE=INPUT_READ_FAILED_FAIL_OPEN\nPROTECT_ACTIVE=0\nFAIL_OPEN=1\n");write_text(fault_path,"INPUT_EVENT_READ_FAILED\n");break;}}if(protect_active)k_ioctl(phys_fd,EVIOCGRAB,0);if(uinput_fd>=0){k_ioctl(uinput_fd,UI_DEV_DESTROY,0);k_close(uinput_fd);}k_close(phys_fd);write_profile();k_exit(0);}
void _start(void){run();}
