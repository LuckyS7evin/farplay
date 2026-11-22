// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay : test du shader ChromaFromLuma (lavapipe). Usage : chroma_test <ChromaFromLuma.glsl> C|L
// Test CfL : image couleur, chroma 4:2:0 (site centre ou gauche), rendu avec/sans hook, PSNR RGB vs 4:4:4.
#include <libplacebo/vulkan.h>
#include <libplacebo/renderer.h>
#include <libplacebo/shaders/custom.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>
#include <string>
static const int W=640,H=360;
static float hsh(int x,int y){unsigned h=x*374761393u+y*668265263u;h=(h^(h>>13))*1274126177u;return (h&0xffff)/65535.f;}
static float vn(float x,float y){int ix=floor(x),iy=floor(y);float fx=x-ix,fy=y-iy;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy);
 float a=hsh(ix,iy),b=hsh(ix+1,iy),c=hsh(ix,iy+1),d=hsh(ix+1,iy+1);return a+(b-a)*fx+(c-a)*fy+(a-b-c+d)*fx*fy;}
int main(int argc,char**argv){
 bool left=argc>2&&argv[2][0]=='L';
 pl_log_params lp={};lp.log_cb=pl_log_color;lp.log_level=PL_LOG_WARN;pl_log log=pl_log_create(PL_API_VER,&lp);
 pl_vulkan_params vp=pl_vulkan_default_params;vp.allow_software=true;pl_vulkan vk=pl_vulkan_create(log,&vp);if(!vk)return 2;pl_gpu gpu=vk->gpu;
 FILE*f=fopen(argv[1],"rb");fseek(f,0,2);long n=ftell(f);rewind(f);std::string src(n,0);if(fread(&src[0],1,n,f)!=(size_t)n)return 2;
 const pl_hook*hook=pl_mpv_user_shader_parse(gpu,src.data(),src.size());if(!hook){puts("parse fail");return 1;}
 std::vector<float> Y(W*H),Cb(W*H),Cr(W*H);
 for(int y=0;y<H;y++)for(int x=0;x<W;x++){
  float r=vn(x/30.f,y/30.f),g=vn(x/30.f+50,y/30.f),b=vn(x/30.f+90,y/30.f+20);
  float t=0.5f+0.5f*vn(x/5.f,y/5.f); r*=t;g*=t;b*=t;
  if(((x/24)+(y/24))%2==0 && x>W/2){r=0.95f;g=0.2f;b=0.1f;} // damier rouge net (HUD)
  if(x>40&&x<200&&y>40&&y<60){r=0.1f;g=0.9f;b=0.3f;}       // barre verte
  float yy=0.2126f*r+0.7152f*g+0.0722f*b;Y[y*W+x]=yy;Cb[y*W+x]=(b-yy)/1.8556f+0.5f;Cr[y*W+x]=(r-yy)/1.5748f+0.5f;}
 // 4:2:0
 int CW=W/2,CH=H/2;std::vector<float> c420(CW*CH*2);
 for(int y=0;y<CH;y++)for(int x=0;x<CW;x++){float sb=0,sr=0,ws=0;
  int ys[2]={2*y,2*y+1};
  for(int yy:ys){ if(left){int xs[3]={2*x-1,2*x,2*x+1};float w[3]={.25f,.5f,.25f};for(int k=0;k<3;k++){int xx=std::max(0,std::min(W-1,xs[k]));sb+=w[k]*Cb[yy*W+xx];sr+=w[k]*Cr[yy*W+xx];ws+=w[k];}}
   else for(int xx=2*x;xx<2*x+2;xx++){sb+=Cb[yy*W+xx];sr+=Cr[yy*W+xx];ws+=1;}}
  c420[(y*CW+x)*2]=sb/ws;c420[(y*CW+x)*2+1]=sr/ws;}
 std::vector<float> c444(W*H*2);for(int i=0;i<W*H;i++){c444[i*2]=Cb[i];c444[i*2+1]=Cr[i];}
 pl_fmt fr=pl_find_named_fmt(gpu,"r32f"),frg=pl_find_named_fmt(gpu,"rg32f"),fo=pl_find_named_fmt(gpu,"rgba32f");
 auto mk=[&](pl_fmt fm,int w,int h,const void*d,bool rd){pl_tex_params tp={};tp.w=w;tp.h=h;tp.format=fm;tp.sampleable=true;tp.renderable=rd;tp.host_writable=true;tp.host_readable=true;tp.storable=rd&&(fm->caps&PL_FMT_CAP_STORABLE);
  pl_tex t=pl_tex_create(gpu,&tp);if(d){pl_tex_transfer_params up={};up.tex=t;up.ptr=(void*)d;pl_tex_upload(gpu,&up);}return t;};
 pl_tex ty=mk(fr,W,H,Y.data(),false),tc4=mk(frg,CW,CH,c420.data(),false),tcf=mk(frg,W,H,c444.data(),false),out=mk(fo,W,H,nullptr,true);
 pl_renderer rr=pl_renderer_create(log,gpu);
 auto run=[&](pl_tex tc,bool sub,bool use,std::vector<float>&res){
  pl_frame s={};s.num_planes=2;s.planes[0].texture=ty;s.planes[0].components=1;s.planes[0].component_mapping[0]=PL_CHANNEL_Y;
  s.planes[1].texture=tc;s.planes[1].components=2;s.planes[1].component_mapping[0]=PL_CHANNEL_CB;s.planes[1].component_mapping[1]=PL_CHANNEL_CR;
  s.repr=pl_color_repr_sdtv;s.repr.sys=PL_COLOR_SYSTEM_BT_709;s.repr.levels=PL_COLOR_LEVELS_FULL;s.color=pl_color_space_srgb;s.crop={0,0,(float)W,(float)H};
  if(sub)pl_frame_set_chroma_location(&s,left?PL_CHROMA_LEFT:PL_CHROMA_CENTER);
  pl_frame t={};t.num_planes=1;t.planes[0].texture=out;t.planes[0].components=4;for(int i=0;i<4;i++)t.planes[0].component_mapping[i]=i;
  t.repr=pl_color_repr_rgb;t.color=pl_color_space_srgb;t.crop={0,0,(float)W,(float)H};
  pl_render_params p=pl_render_default_params;p.hooks=&hook;p.num_hooks=use?1:0;p.deband_params=nullptr;p.dither_params=nullptr;
  if(!pl_render_image(rr,&s,&t,&p)){puts("render fail");exit(1);}
  res.resize(W*H*4);pl_tex_transfer_params dl={};dl.tex=out;dl.ptr=res.data();pl_tex_download(gpu,&dl);};
 std::vector<float> ref,bil,cfl;run(tcf,false,false,ref);run(tc4,true,false,bil);run(tc4,true,true,cfl);
 auto psnr=[&](std::vector<float>&a,int x0,int x1){double s=0;int c=0;for(int y=4;y<H-4;y++)for(int x=x0;x<x1;x++)for(int k=0;k<3;k++){double d=a[(y*W+x)*4+k]-ref[(y*W+x)*4+k];s+=d*d;c++;}return 10*log10(1.0/(s/c));};
 double b0=psnr(bil,4,W-4),b1=psnr(cfl,4,W-4),h0=psnr(bil,W/2+4,W-4),h1=psnr(cfl,W/2+4,W-4);
 printf("site %s : global bilinéaire %.2f dB -> CfL %.2f dB | damier HUD %.2f -> %.2f dB\n",left?"gauche":"centre",b0,b1,h0,h1);
 return (b1<b0+0.5||h1<h0)?1:0;}
