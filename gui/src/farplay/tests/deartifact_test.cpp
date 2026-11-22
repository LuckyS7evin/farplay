// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay : test du shader de réduction d'artefacts (lavapipe). Image
// synthétique + bruit + décalages de blocs 8x8 ; échec si le gain < 1,5 dB.
// Usage : deartifact_test <Deartifact.glsl> [force]
#include <libplacebo/vulkan.h>
#include <libplacebo/renderer.h>
#include <libplacebo/shaders/custom.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>
#include <random>
#include <string>
static const int W=640,H=360;
static float hsh(int x,int y){unsigned h=x*374761393u+y*668265263u;h=(h^(h>>13))*1274126177u;return (h&0xffff)/65535.f;}
static float vnoise(float x,float y){int ix=floor(x),iy=floor(y);float fx=x-ix,fy=y-iy;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy);
 float a=hsh(ix,iy),b=hsh(ix+1,iy),c=hsh(ix,iy+1),d=hsh(ix+1,iy+1);return a+(b-a)*fx+(c-a)*fy+(a-b-c+d)*fx*fy;}
int main(int argc,char**argv){
 pl_log_params lp={};lp.log_cb=pl_log_color;lp.log_level=PL_LOG_WARN;pl_log log=pl_log_create(PL_API_VER,&lp);
 pl_vulkan_params vp=pl_vulkan_default_params;vp.allow_software=true;pl_vulkan vk=pl_vulkan_create(log,&vp);if(!vk)return 2;pl_gpu gpu=vk->gpu;
 FILE*f=fopen(argv[1],"rb");fseek(f,0,2);long n=ftell(f);rewind(f);std::string src(n,0);if(fread(&src[0],1,n,f)!=(size_t)n)return 2;
 const pl_hook*hook=pl_mpv_user_shader_parse(gpu,src.data(),src.size());if(!hook){puts("parse fail");return 1;}
 float hval=argc>2?atof(argv[2]):0.02f;
 for(int i=0;i<hook->num_parameters;i++){auto&p=hook->parameters[i];if(std::string(p.name)=="farplay_denoise_h")p.data->f=hval;}
 std::vector<float> clean(W*H),noisy(W*H);std::mt19937 rng(1);std::normal_distribution<float> g(0,0.02f);
 std::vector<float> boff((W/8+1)*(H/8+1));for(auto&v:boff)v=g(rng)*0.5f;
 for(int y=0;y<H;y++)for(int x=0;x<W;x++){float v=0.15f+0.5f*vnoise(x/40.f,y/40.f)+0.15f*vnoise(x/6.f,y/6.f);
  if(x>W/2&&x<W/2+120&&y>100&&y<220)v=0.9f; // bloc HUD net
  clean[y*W+x]=v;noisy[y*W+x]=v+g(rng)+boff[(y/8)*(W/8+1)+x/8];}
 pl_fmt fr=pl_find_named_fmt(gpu,"r32f"),frg=pl_find_named_fmt(gpu,"rg16"),fo=pl_find_named_fmt(gpu,"rgba32f");
 auto mk=[&](pl_fmt fm,int w,int h,const void*data,bool rd){pl_tex_params tp={};tp.w=w;tp.h=h;tp.format=fm;tp.sampleable=true;tp.renderable=rd;tp.host_writable=true;tp.host_readable=true;tp.blit_dst=rd;tp.storable=rd&&(fm->caps&PL_FMT_CAP_STORABLE);
  pl_tex t=pl_tex_create(gpu,&tp);if(data){pl_tex_transfer_params up={};up.tex=t;up.ptr=(void*)data;pl_tex_upload(gpu,&up);}return t;};
 std::vector<uint16_t> ch((W/2)*(H/2)*2,32768);pl_tex tc=mk(frg,W/2,H/2,ch.data(),false);
 pl_renderer rr=pl_renderer_create(log,gpu);pl_tex out=mk(fo,W,H,nullptr,true);
 auto run=[&](const std::vector<float>&img,bool use,std::vector<float>&res){
  pl_tex ty=mk(fr,W,H,img.data(),false);
  pl_frame fsrc={};fsrc.num_planes=2;fsrc.planes[0].texture=ty;fsrc.planes[0].components=1;fsrc.planes[0].component_mapping[0]=PL_CHANNEL_Y;
  fsrc.planes[1].texture=tc;fsrc.planes[1].components=2;fsrc.planes[1].component_mapping[0]=PL_CHANNEL_CB;fsrc.planes[1].component_mapping[1]=PL_CHANNEL_CR;
  fsrc.repr=pl_color_repr_sdtv;fsrc.repr.sys=PL_COLOR_SYSTEM_BT_709;fsrc.repr.levels=PL_COLOR_LEVELS_FULL;fsrc.color=pl_color_space_srgb;
  fsrc.crop={0,0,(float)W,(float)H};
  pl_frame tgt={};tgt.num_planes=1;tgt.planes[0].texture=out;tgt.planes[0].components=4;for(int i=0;i<4;i++)tgt.planes[0].component_mapping[i]=i;
  tgt.repr=pl_color_repr_rgb;tgt.color=pl_color_space_srgb;tgt.crop={0,0,(float)W,(float)H};
  pl_render_params p=pl_render_fast_params;p.hooks=&hook;p.num_hooks=use?1:0;p.deband_params=nullptr;
  if(!pl_render_image(rr,&fsrc,&tgt,&p)){puts("render fail");exit(1);}
  std::vector<float> o(W*H*4);pl_tex_transfer_params dl={};dl.tex=out;dl.ptr=o.data();pl_tex_download(gpu,&dl);
  res.resize(W*H);for(int i=0;i<W*H;i++)res[i]=o[i*4+1];pl_tex_destroy(gpu,&ty);};
 std::vector<float> rc,rn,rd;run(clean,false,rc);run(noisy,false,rn);run(noisy,true,rd);
 auto psnr=[&](std::vector<float>&a,int x0,int x1,int y0,int y1){double s=0;int c=0;for(int y=y0;y<y1;y++)for(int x=x0;x<x1;x++){double d=a[y*W+x]-rc[y*W+x];s+=d*d;c++;}return 10*log10(1.0/(s/c));};
 double g0=psnr(rn,4,W-4,4,H-4),g1=psnr(rd,4,W-4,4,H-4),e0=psnr(rn,W/2-4,W/2+4,100,220),e1=psnr(rd,W/2-4,W/2+4,100,220);
 printf("h=%.3f  global: bruité %.2f dB -> filtré %.2f dB | bord HUD: %.2f -> %.2f dB\n",hval,g0,g1,e0,e1);
 return (g1-g0<1.5||e1<e0)?1:0;}
