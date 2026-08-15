# Little Stream Detector (LSD)
# Copyright (C) 2026 Jan Simak
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: GPL-3.0-only
#requires -version 5.1
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
Add-Type -Language CSharp -TypeDefinition @"
using System; using System.Diagnostics; using System.Text; using System.Runtime.InteropServices; using System.Globalization;
public static class LSDConsole { [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h,int n); public static void Hide(){var h=GetConsoleWindow();if(h!=IntPtr.Zero)ShowWindow(h,0);} }
public sealed class NativeMediaInfo {
 public long Length; public DateTime ModifiedUtc; public string Container="Unknown"; public string Detail="";
 public long BytesRead; public double ReadSeconds; public double MiBPerSecond; public string DocType=""; public long TimecodeScale=1000000; public double DurationSeconds; public string MuxingApp=""; public string WritingApp=""; public readonly System.Collections.Generic.List<NativeTrack> Tracks=new System.Collections.Generic.List<NativeTrack>();
}
public sealed class NativeTrack {
 public long Number; public long Type; public string CodecId=""; public string Language="und"; public long Width; public long Height; public double SamplingRate; public double OutputSamplingRate; public long Channels; public byte[] CodecPrivate;
 public string Profile=""; public double Level; public int NalLengthSize; public int Log2MaxFrameNum=4,PicOrderCntType,Log2MaxPicOrderCntLsb=4,PicInitQpMinus26,NumRefL0,NumRefL1; public bool FrameMbsOnly=true,BottomFieldPicOrderInFramePresent,RedundantPicCntPresent,DeblockingFilterControlPresent; public string Chroma=""; public int BitDepth; public int RefFrames; public double FrameRate; public string PixelAspect="";
 public bool Cabac,WeightedPred,Transform8x8,Sbr,Ps,HevcConfig,HevcTier,HevcDependentSliceSegments,HevcOutputFlagPresent,HevcCabacInitPresent,HevcCuQpDeltaEnabled,HevcWeightedPred,HevcWeightedBipred,HevcTilesEnabled,HevcWppEnabled,HevcDeblockingControlPresent,HevcDeblockingOverrideEnabled,HevcLoopFilterAcrossSlices,HevcListsModificationPresent; public int HevcProfile,HevcLevel,HevcTemporalLayers,HevcExtraSliceHeaderBits,HevcNumRefL0,HevcNumRefL1,HevcPicInitQpMinus26,HevcDiffCuQpDeltaDepth; public int WeightedBipred; public string ColorPrimaries="",ColorTransfer="",ColorMatrix="",ColorRange=""; public int CoreSampleRate,OutputSampleRate,CoreAudioChannels,AudioChannels; public string AudioProfile="";
 public string Kind { get { return Type==1?"video":Type==2?"audio":Type==17?"subtitle":"other"; } }
}
public static class NativeMediaProbe {
 static bool Eq(byte[] b,int o,params byte[] v){if(b==null||o<0||o+v.Length>b.Length)return false;for(int i=0;i<v.Length;i++)if(b[o+i]!=v[i])return false;return true;}
 static string Ascii(byte[] b,int o,int n){return Encoding.ASCII.GetString(b,o,n);}
 static ulong ReadId(System.IO.Stream s,out int len){int x=s.ReadByte();if(x<0){len=0;return 0;}byte b=(byte)x;int mask=0x80;len=1;while(len<=4&&(b&mask)==0){mask>>=1;len++;}if(len>4)throw new System.IO.InvalidDataException("Invalid EBML ID");ulong v=b;for(int i=1;i<len;i++){x=s.ReadByte();if(x<0)throw new System.IO.EndOfStreamException();v=(v<<8)|(byte)x;}return v;}
 static ulong ReadSize(System.IO.Stream s,out int len,out bool unknown){int x=s.ReadByte();if(x<0){len=0;unknown=false;return 0;}byte b=(byte)x;int mask=0x80;len=1;while(len<=8&&(b&mask)==0){mask>>=1;len++;}if(len>8)throw new System.IO.InvalidDataException("Invalid EBML size");ulong v=(ulong)(b&(mask-1));for(int i=1;i<len;i++){x=s.ReadByte();if(x<0)throw new System.IO.EndOfStreamException();v=(v<<8)|(byte)x;}ulong all=(1UL<<(7*len))-1;unknown=v==all;return v;}
 static ulong UInt(System.IO.Stream s,long n){ulong v=0;for(long i=0;i<n;i++){int x=s.ReadByte();if(x<0)throw new System.IO.EndOfStreamException();v=(v<<8)|(byte)x;}return v;}
 static string Utf8(System.IO.Stream s,long n){if(n<0||n>1048576)throw new System.IO.InvalidDataException();byte[] b=new byte[(int)n];int o=0,k;while(o<b.Length&&(k=s.Read(b,o,b.Length-o))>0)o+=k;return Encoding.UTF8.GetString(b,0,o).TrimEnd('\0');}
 static double Float(System.IO.Stream s,long n){byte[] b=new byte[(int)n];for(int o=0;o<b.Length;){int k=s.Read(b,o,b.Length-o);if(k<=0)throw new System.IO.EndOfStreamException();o+=k;}if(BitConverter.IsLittleEndian)Array.Reverse(b);if(n==4)return BitConverter.ToSingle(b,0);if(n==8)return BitConverter.ToDouble(b,0);return 0;}
 static bool Master(ulong id){return id==0x1A45DFA3||id==0x18538067||id==0x1549A966||id==0x1654AE6B||id==0xAE||id==0xE0||id==0xE1;}

 static byte[] Binary(System.IO.Stream s,long n){if(n<0||n>16*1024*1024)throw new System.IO.InvalidDataException("CodecPrivate is too large");byte[] b=new byte[(int)n];int o=0;while(o<b.Length){int k=s.Read(b,o,b.Length-o);if(k<=0)throw new System.IO.EndOfStreamException();o+=k;}return b;}
 sealed class Bits { readonly byte[] b; int p; public Bits(byte[] x){b=x;} public int Position{get{return p;}set{p=Math.Max(0,Math.Min(value,b.Length*8));}} public int Remaining{get{return b.Length*8-p;}} public int Bit(){if(p>=b.Length*8)return 0;return (b[p>>3]>>(7-(p++&7)))&1;} public bool MoreRbspData(){if(Remaining<=0)return false;int saved=p;try{if(Bit()!=1)return true;while(Remaining>0)if(Bit()!=0)return true;return false;}finally{p=saved;}} public uint U(int n){uint v=0;while(n-->0)v=(v<<1)|(uint)Bit();return v;} public uint UE(){int z=0;while(Bit()==0&&z<31)z++;return ((1u<<z)-1)+U(z);} public int SE(){uint v=UE();return (v&1)!=0?(int)((v+1)>>1):-(int)(v>>1);} }
 static byte[] Rbsp(byte[] n,int off,int len){var x=new System.Collections.Generic.List<byte>(len);int zeros=0;for(int i=off;i<off+len;i++){byte v=n[i];if(zeros==2&&v==3){zeros=0;continue;}x.Add(v);zeros=v==0?zeros+1:0;}return x.ToArray();}
 static string ColorName(int v){switch(v){case 1:return "bt709";case 4:return "bt470m";case 5:return "bt470bg";case 6:return "smpte170m";case 7:return "smpte240m";case 9:return "bt2020";default:return v>0?"code "+v:"";}}
 static string ProfileName(int p){switch(p){case 66:return "Baseline";case 77:return "Main";case 88:return "Extended";case 100:return "High";case 110:return "High 10";case 122:return "High 4:2:2";case 244:return "High 4:4:4";default:return "Profile "+p;}}
 static void Scaling(Bits b,int n){int last=8,next=8;for(int j=0;j<n;j++){if(next!=0)next=(last+b.SE()+256)%256;last=next==0?last:next;}}
 static void ParseSps(byte[] nal,NativeTrack t){byte[] r=Rbsp(nal,1,nal.Length-1);var b=new Bits(r);int profile=(int)b.U(8);b.U(8);int level=(int)b.U(8);b.UE();int chroma=1,bd=8;if(profile==100||profile==110||profile==122||profile==244||profile==44||profile==83||profile==86||profile==118||profile==128||profile==138||profile==139||profile==134){chroma=(int)b.UE();if(chroma==3)b.Bit();bd=8+(int)b.UE();b.UE();b.Bit();if(b.Bit()!=0){int n=chroma!=3?8:12;for(int i=0;i<n;i++)if(b.Bit()!=0)Scaling(b,i<6?16:64);}}int log2=(int)b.UE()+4;int poc=(int)b.UE();t.Log2MaxFrameNum=log2;t.PicOrderCntType=poc;if(poc==0){t.Log2MaxPicOrderCntLsb=(int)b.UE()+4;}else if(poc==1){b.Bit();b.SE();b.SE();uint c=b.UE();for(int i=0;i<c;i++)b.SE();}int refs=(int)b.UE();b.Bit();int w=(int)b.UE(),h=(int)b.UE();int frameMbs=b.Bit();t.FrameMbsOnly=frameMbs!=0;if(frameMbs==0)b.Bit();b.Bit();int cropL=0,cropR=0,cropT=0,cropB=0;if(b.Bit()!=0){cropL=(int)b.UE();cropR=(int)b.UE();cropT=(int)b.UE();cropB=(int)b.UE();}int width=(w+1)*16,height=(2-frameMbs)*(h+1)*16;int subW=chroma==3?1:2,subH=chroma==1?2:1;width-=(cropL+cropR)*subW;height-=(cropT+cropB)*subH*(2-frameMbs);t.Profile=ProfileName(profile);t.Level=level/10.0;t.Chroma=chroma==0?"YUV 4:0:0":chroma==1?"YUV 4:2:0":chroma==2?"YUV 4:2:2":"YUV 4:4:4";t.BitDepth=bd;t.RefFrames=refs;if(t.Width==0)t.Width=width;if(t.Height==0)t.Height=height;
  if(b.Bit()!=0){int sarW=0,sarH=0;if(b.Bit()!=0){int idc=(int)b.U(8);int[,] sar={{0,0},{1,1},{12,11},{10,11},{16,11},{40,33},{24,11},{20,11},{32,11},{80,33},{18,11},{15,11},{64,33},{160,99},{4,3},{3,2},{2,1}};if(idc==255){sarW=(int)b.U(16);sarH=(int)b.U(16);}else if(idc>0&&idc<17){sarW=sar[idc,0];sarH=sar[idc,1];}}if(sarW>0&&sarH>0)t.PixelAspect=sarW+":"+sarH;if(b.Bit()!=0)b.Bit();if(b.Bit()!=0){b.U(3);int full=b.Bit();t.ColorRange=full!=0?"pc":"tv";if(b.Bit()!=0){int cp=(int)b.U(8),tr=(int)b.U(8),mx=(int)b.U(8);t.ColorPrimaries=ColorName(cp);t.ColorTransfer=ColorName(tr);t.ColorMatrix=ColorName(mx);}}if(b.Bit()!=0){b.UE();b.UE();}if(b.Bit()!=0){uint units=b.U(32),scale=b.U(32);b.Bit();if(units>0&&scale>0)t.FrameRate=scale/(2.0*units);}}
 }
 static void ParsePps(byte[] nal,NativeTrack t){var b=new Bits(Rbsp(nal,1,nal.Length-1));b.UE();b.UE();t.Cabac=b.Bit()!=0;t.BottomFieldPicOrderInFramePresent=b.Bit()!=0;uint groups=b.UE();if(groups>0)return;t.NumRefL0=(int)b.UE();t.NumRefL1=(int)b.UE();t.WeightedPred=b.Bit()!=0;t.WeightedBipred=(int)b.U(2);t.PicInitQpMinus26=b.SE();b.SE();b.SE();t.DeblockingFilterControlPresent=b.Bit()!=0;b.Bit();t.RedundantPicCntPresent=b.Bit()!=0;if(b.MoreRbspData()){t.Transform8x8=b.Bit()!=0;if(b.Bit()!=0){int scalingCount=t.Chroma=="YUV 4:4:4"?12:8;for(int i=0;i<scalingCount;i++)if(b.Bit()!=0)Scaling(b,i<6?16:64);}b.SE();}}
 static void ParseAvc(byte[] c,NativeTrack t){if(c==null||c.Length<7||c[0]!=1)return;t.Profile=ProfileName(c[1]);t.Level=c[3]/10.0;t.NalLengthSize=(c[4]&3)+1;int p=6,ns=c[5]&31;for(int i=0;i<ns&&p+2<=c.Length;i++){int n=(c[p]<<8)|c[p+1];p+=2;if(p+n>c.Length)break;byte[] nal=new byte[n];Array.Copy(c,p,nal,0,n);p+=n;ParseSps(nal,t);}if(p<c.Length){int np=c[p++];for(int i=0;i<np&&p+2<=c.Length;i++){int n=(c[p]<<8)|c[p+1];p+=2;if(p+n>c.Length)break;byte[] nal=new byte[n];Array.Copy(c,p,nal,0,n);p+=n;ParsePps(nal,t);}}}
 static int[] AacRates={96000,88200,64000,48000,44100,32000,24000,22050,16000,12000,11025,8000,7350};
 static int AacRate(Bits b){int i=(int)b.U(4);return i==15?(int)b.U(24):(i>=0&&i<AacRates.Length?AacRates[i]:0);}
 static void ParseAac(byte[] c,NativeTrack t){if(c==null||c.Length<2)return;var b=new Bits(c);int aot=(int)b.U(5);if(aot==31)aot=32+(int)b.U(6);int rate=AacRate(b),ch=(int)b.U(4),coreCh=ch,outRate=rate;if(aot==5||aot==29){t.Sbr=true;t.Ps=aot==29;outRate=AacRate(b);aot=(int)b.U(5);}else{for(int pos=b.Position;pos+16<=c.Length*8;pos++){b.Position=pos;if(b.U(11)==0x2B7){int extAot=(int)b.U(5);if(extAot==5&&b.Bit()!=0){t.Sbr=true;outRate=AacRate(b);if(b.Remaining>=12&&b.U(11)==0x548)t.Ps=b.Bit()!=0;}break;}}}if(t.OutputSamplingRate>0)outRate=(int)t.OutputSamplingRate;if(t.Sbr&&outRate==rate&&rate>0)outRate=rate*2;if(t.Ps&&ch==1)ch=2;t.CoreSampleRate=rate;t.OutputSampleRate=outRate;t.CoreAudioChannels=coreCh;t.AudioChannels=ch;t.AudioProfile=t.Sbr?(t.Ps?"HE-AAC v2":"HE-AAC"):(aot==2?"AAC-LC":"AAC object "+aot);}
 static string HevcProfileName(int p){switch(p){case 1:return "Main";case 2:return "Main 10";case 3:return "Main Still Picture";default:return p>0?"Profile "+p:"";}}
 static void ParseHevcPpsEarly(byte[] nal,NativeTrack t){
  if(nal==null||nal.Length<3)return;var b=new Bits(Rbsp(nal,2,nal.Length-2));
  b.UE();b.UE();t.HevcDependentSliceSegments=b.Bit()!=0;t.HevcOutputFlagPresent=b.Bit()!=0;t.HevcExtraSliceHeaderBits=(int)b.U(3);
  b.Bit();t.HevcCabacInitPresent=b.Bit()!=0;t.HevcNumRefL0=(int)b.UE();t.HevcNumRefL1=(int)b.UE();t.HevcPicInitQpMinus26=b.SE();b.Bit();b.Bit();
  t.HevcCuQpDeltaEnabled=b.Bit()!=0;if(t.HevcCuQpDeltaEnabled)t.HevcDiffCuQpDeltaDepth=(int)b.UE();b.SE();b.SE();b.Bit();t.HevcWeightedPred=b.Bit()!=0;t.HevcWeightedBipred=b.Bit()!=0;b.Bit();
  t.HevcTilesEnabled=b.Bit()!=0;t.HevcWppEnabled=b.Bit()!=0;
  if(t.HevcTilesEnabled){int cols=(int)b.UE(),rows=(int)b.UE();int uniform=b.Bit();if(uniform==0){for(int i=0;i<cols;i++)b.UE();for(int i=0;i<rows;i++)b.UE();}b.Bit();}
  b.Bit();t.HevcDeblockingControlPresent=b.Bit()!=0;if(t.HevcDeblockingControlPresent){t.HevcDeblockingOverrideEnabled=b.Bit()!=0;int disabled=b.Bit();if(disabled==0){b.SE();b.SE();}}
  t.HevcLoopFilterAcrossSlices=b.Bit()!=0;b.Bit();t.HevcListsModificationPresent=b.Bit()!=0;
 }
 static void ParseHevc(byte[] c,NativeTrack t){
  if(c==null||c.Length<23||c[0]!=1)return;t.HevcConfig=true;t.HevcProfile=c[1]&31;t.HevcTier=(c[1]&0x20)!=0;t.HevcLevel=c[12];t.Profile=HevcProfileName(t.HevcProfile);t.Level=t.HevcLevel/30.0;t.Chroma=(c[16]&3)==0?"YUV 4:0:0":(c[16]&3)==1?"YUV 4:2:0":(c[16]&3)==2?"YUV 4:2:2":"YUV 4:4:4";t.BitDepth=8+(c[17]&7);t.NalLengthSize=(c[21]&3)+1;t.HevcTemporalLayers=(c[21]>>3)&7;
  int p=23;int arrays=c[22];for(int a=0;a<arrays&&p+3<=c.Length;a++){int type=c[p]&63;int num=(c[p+1]<<8)|c[p+2];p+=3;for(int i=0;i<num&&p+2<=c.Length;i++){int n=(c[p]<<8)|c[p+1];p+=2;if(n<0||p+n>c.Length)return;if(type==34){byte[] nal=new byte[n];Array.Copy(c,p,nal,0,n);ParseHevcPpsEarly(nal,t);}p+=n;}}
  try{var sps=HevcSpsProbeParser.ParseHvcc(c);if(sps.VideoSignalTypePresent)t.ColorRange=sps.FullRange?"pc":"tv";if(sps.ColourDescriptionPresent){t.ColorPrimaries=ColorName(sps.ColourPrimaries);t.ColorTransfer=ColorName(sps.TransferCharacteristics);t.ColorMatrix=ColorName(sps.MatrixCoefficients);}}catch{}
 }
 static void ParsePrivate(NativeTrack t){try{if(t.CodecId=="V_MPEG4/ISO/AVC")ParseAvc(t.CodecPrivate,t);else if(t.CodecId=="V_MPEGH/ISO/HEVC")ParseHevc(t.CodecPrivate,t);else if(t.CodecId=="A_AAC"){ParseAac(t.CodecPrivate,t);if(!t.Ps&&t.Channels>0){t.CoreAudioChannels=(int)t.Channels;t.AudioChannels=(int)t.Channels;}else if(t.CoreAudioChannels<=0&&t.Channels>0)t.CoreAudioChannels=(int)t.Channels;if(t.OutputSamplingRate>0)t.OutputSampleRate=(int)t.OutputSamplingRate;}}catch{}}
 static void ParseMatroska(System.IO.FileStream fs,NativeMediaInfo r){fs.Position=0;var ends=new System.Collections.Generic.Stack<long>();NativeTrack track=null;long limit=Math.Min(fs.Length,64L*1024*1024);while(fs.Position<limit){while(ends.Count>0&&fs.Position>=ends.Peek()){long e=ends.Pop();if(track!=null&&ends.Count<3){ParsePrivate(track);if(!r.Tracks.Contains(track))r.Tracks.Add(track);track=null;}}long start=fs.Position;int il,sl;bool unk;ulong id;try{id=ReadId(fs,out il);if(il==0)break;ulong size=ReadSize(fs,out sl,out unk);long data=fs.Position;long end=unk?limit:Math.Min(limit,data+(long)size);if(id==0x1F43B675)break;if(id==0xAE){track=new NativeTrack();ends.Push(end);continue;}if(Master(id)){ends.Push(end);continue;}long n=end-data;if(n<0)break;
   if(id==0x4282)r.DocType=Utf8(fs,n);else if(id==0x2AD7B1)r.TimecodeScale=(long)UInt(fs,n);else if(id==0x4489)r.DurationSeconds=Float(fs,n)*r.TimecodeScale/1000000000.0;else if(id==0x4D80)r.MuxingApp=Utf8(fs,n);else if(id==0x5741)r.WritingApp=Utf8(fs,n);else if(track!=null&&id==0xD7)track.Number=(long)UInt(fs,n);else if(track!=null&&id==0x83)track.Type=(long)UInt(fs,n);else if(track!=null&&id==0x86)track.CodecId=Utf8(fs,n);else if(track!=null&&id==0x22B59C)track.Language=Utf8(fs,n);else if(track!=null&&id==0xB0)track.Width=(long)UInt(fs,n);else if(track!=null&&id==0xBA)track.Height=(long)UInt(fs,n);else if(track!=null&&id==0xB5)track.SamplingRate=Float(fs,n);else if(track!=null&&id==0x78B5)track.OutputSamplingRate=Float(fs,n);else if(track!=null&&id==0x9F)track.Channels=(long)UInt(fs,n);else if(track!=null&&id==0x63A2)track.CodecPrivate=Binary(fs,n);else fs.Position=end;
   if(fs.Position<end)fs.Position=end;
  }catch{fs.Position=Math.Min(limit,start+1);}
 }if(track!=null&&!r.Tracks.Contains(track)){ParsePrivate(track);r.Tracks.Add(track);}}

 public static NativeMediaInfo Inspect(string path,bool streamWholeFile){
  var r=new NativeMediaInfo();var fi=new System.IO.FileInfo(path);r.Length=fi.Length;r.ModifiedUtc=fi.LastWriteTimeUtc;
  var sw=Stopwatch.StartNew();long read=0;byte[] head=new byte[4096];
  using(var fs=new System.IO.FileStream(path,System.IO.FileMode.Open,System.IO.FileAccess.Read,System.IO.FileShare.ReadWrite,4*1024*1024,System.IO.FileOptions.SequentialScan)){
   int n=fs.Read(head,0,head.Length);read+=n;
   if(Eq(head,0,0x1A,0x45,0xDF,0xA3)){r.Container="Matroska / WebM";r.Detail="EBML";ParseMatroska(fs,r);}
   else if(n>=12&&Ascii(head,0,4)=="RIFF"&&Ascii(head,8,4)=="AVI "){r.Container="AVI";r.Detail="RIFF AVI";}
   else if(n>=12&&Ascii(head,4,4)=="ftyp"){r.Container="MP4 / MOV";r.Detail="ISO Base Media";}
   else if(n>=1&&head[0]==0x47&&(n<189||head[188]==0x47)){r.Container="MPEG-TS";r.Detail="Transport Stream";}
   else if(Eq(head,0,0,0,0,1)||Eq(head,0,0,0,1)){r.Container="Raw H.264 / HEVC";r.Detail="Annex B";}
   if(streamWholeFile){byte[] buf=new byte[4*1024*1024];int got;while((got=fs.Read(buf,0,buf.Length))>0)read+=got;}
  }
  sw.Stop();r.BytesRead=read;r.ReadSeconds=sw.Elapsed.TotalSeconds;r.MiBPerSecond=r.ReadSeconds>0?(read/1048576.0)/r.ReadSeconds:0;return r;
 }
}
public sealed class H264CabacContext {
 public int State;
 public int Mps;
 public H264CabacContext(int state,int mps){State=state;Mps=mps;}
}
public sealed class H264CabacArithmeticDecoder {
 readonly byte[] data; int bitPosition; uint range=510,offset;
 static readonly byte[,] RangeLps=new byte[64,4]{
 {128,176,208,240},{128,167,197,227},{128,158,187,216},{123,150,178,205},{116,142,169,195},{111,135,160,185},{105,128,152,175},{100,122,144,166},
 {95,116,137,158},{90,110,130,150},{85,104,123,142},{81,99,117,135},{77,94,111,128},{73,89,105,122},{69,85,100,116},{66,80,95,110},
 {62,76,90,104},{59,72,86,99},{56,69,81,94},{53,65,77,89},{51,62,73,85},{48,59,69,80},{46,56,66,76},{43,53,63,72},
 {41,50,59,69},{39,48,56,65},{37,45,54,62},{35,43,51,59},{33,41,48,56},{32,39,46,53},{30,37,43,50},{29,35,41,48},
 {27,33,39,45},{26,31,37,43},{24,30,35,41},{23,28,33,39},{22,27,32,37},{21,26,30,35},{20,24,29,33},{19,23,27,31},
 {18,22,26,30},{17,21,25,28},{16,20,23,27},{15,19,22,25},{14,18,21,24},{14,17,20,23},{13,16,19,22},{12,15,18,21},
 {12,14,17,20},{11,14,16,19},{11,13,15,18},{10,12,15,17},{10,12,14,16},{9,11,13,15},{9,11,12,14},{8,10,12,14},
 {8,9,11,13},{7,9,11,12},{7,9,10,12},{7,8,10,11},{6,8,9,11},{6,7,9,10},{6,7,8,9},{2,2,2,2}};
 static readonly byte[] TransMps={1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,62,63};
 static readonly byte[] TransLps={0,0,1,2,2,4,4,5,6,7,8,9,9,11,11,12,13,13,15,15,16,16,18,18,19,19,21,21,22,22,23,24,24,25,26,26,27,27,28,29,29,30,30,30,31,32,32,33,33,33,34,34,35,35,35,36,36,36,37,37,37,38,38,63};
 public H264CabacArithmeticDecoder(byte[] rbsp,int byteOffset){data=rbsp;bitPosition=byteOffset*8;for(int i=0;i<9;i++)offset=(offset<<1)|(uint)ReadBit();}
 int ReadBit(){if(bitPosition>=data.Length*8)throw new System.IO.EndOfStreamException("CABAC input ended");return (data[bitPosition>>3]>>(7-(bitPosition++&7)))&1;}
 void Renorm(){while(range<256){range<<=1;offset=(offset<<1)|(uint)ReadBit();}}
 public int DecodeBin(H264CabacContext c){int q=(int)((range>>6)&3);uint lps=RangeLps[c.State,q];range-=lps;int bin;if(offset>=range){offset-=range;range=lps;bin=1-c.Mps;if(c.State==0)c.Mps^=1;c.State=TransLps[c.State];}else{bin=c.Mps;c.State=TransMps[c.State];}Renorm();return bin;}
 public int DecodeBypass(){offset=(offset<<1)|(uint)ReadBit();if(offset>=range){offset-=range;return 1;}return 0;}
 public int DecodeTerminate(){range-=2;if(offset>=range)return 1;Renorm();return 0;}
 public static H264CabacContext Initialize(int m,int n,int sliceQpY){int pre=Math.Max(1,Math.Min(126,((m*sliceQpY)>>4)+n));return pre<=63?new H264CabacContext(63-pre,0):new H264CabacContext(pre-64,1);}
}
public sealed class H264RawBitReader {
 readonly byte[] data; int position;
 public H264RawBitReader(byte[] rbsp){if(rbsp==null)throw new ArgumentNullException("rbsp");data=rbsp;}
 public int Position { get { return position; } }
 public int Remaining { get { return data.Length*8-position; } }
 public int ReadBit(){if(position>=data.Length*8)throw new System.IO.EndOfStreamException("H.264 RBSP ended");return (data[position>>3]>>(7-(position++&7)))&1;}
 public uint ReadBits(int count){if(count<0||count>32)throw new ArgumentOutOfRangeException("count");uint value=0;for(int i=0;i<count;i++)value=(value<<1)|(uint)ReadBit();return value;}
 public uint ReadUE(){int leading=0;while(ReadBit()==0){leading++;if(leading>31)throw new System.IO.InvalidDataException("Exp-Golomb code is too long");}return ((1u<<leading)-1)+ReadBits(leading);}
 public int ReadSE(){uint value=ReadUE();return (value&1)!=0?(int)((value+1)>>1):-(int)(value>>1);}
 public void AlignCabac(){while((position&7)!=0){if(ReadBit()!=1)throw new System.IO.InvalidDataException("Invalid cabac_alignment_one_bit");}}
 public int ByteOffset { get { if((position&7)!=0)throw new InvalidOperationException("Reader is not byte aligned");return position>>3; } }
}
public sealed class H264SliceHeaderConfig {
 public int Log2MaxFrameNum=4;
 public int PicOrderCntType;
 public int Log2MaxPicOrderCntLsb=4;
 public bool FrameMbsOnly=true;
 public bool BottomFieldPicOrderInFramePresent;
 public bool RedundantPicCntPresent;
 public bool EntropyCodingCabac=true;
 public int PicInitQpMinus26;
 public bool DeblockingFilterControlPresent;
 public bool WeightedPred;
 public int WeightedBipredIdc;
 public int ChromaArrayType=1; public int NumRefIdxL0DefaultActiveMinus1; public int NumRefIdxL1DefaultActiveMinus1;
}
public static class H264SliceHeaderParser {
 static void RefPicListModification(H264RawBitReader b,int sliceType){
  int t=sliceType%5;if(t!=2&&t!=4){if(b.ReadBit()!=0){uint idc;do{idc=b.ReadUE();if(idc==0||idc==1)b.ReadUE();else if(idc==2)b.ReadUE();else if(idc>3)throw new System.IO.InvalidDataException("Invalid ref_pic_list_modification idc");}while(idc!=3);}}
  if(t==1){if(b.ReadBit()!=0){uint idc;do{idc=b.ReadUE();if(idc==0||idc==1)b.ReadUE();else if(idc==2)b.ReadUE();else if(idc>3)throw new System.IO.InvalidDataException("Invalid list1 modification idc");}while(idc!=3);}}
 }
 static void DecRefPicMarking(H264RawBitReader b,bool idr,int nalRefIdc){if(nalRefIdc==0)return;if(idr){b.ReadBit();b.ReadBit();return;}if(b.ReadBit()!=0){uint op;do{op=b.ReadUE();if(op==1||op==3)b.ReadUE();if(op==2)b.ReadUE();if(op==3||op==6)b.ReadUE();if(op==4)b.ReadUE();if(op>6)throw new System.IO.InvalidDataException("Invalid memory_management_control_operation");}while(op!=0);}}
 static void SkipPredWeightTable(H264RawBitReader b,int sliceType,int chromaArrayType,int l0,int l1){int luma=(int)b.ReadUE();int chroma=0;if(chromaArrayType!=0)chroma=(int)b.ReadUE();for(int list=0;list<(sliceType%5==1?2:1);list++){int count=list==0?l0:l1;for(int i=0;i<=count;i++){if(b.ReadBit()!=0){b.ReadSE();b.ReadSE();}if(chromaArrayType!=0&&b.ReadBit()!=0){for(int j=0;j<2;j++){b.ReadSE();b.ReadSE();}}}}}
 public static H264SliceQpState Parse(byte[] rbsp,int nalUnitType,int nalRefIdc,H264SliceHeaderConfig c){
  if(rbsp==null)throw new ArgumentNullException("rbsp");if(c==null)throw new ArgumentNullException("c");var b=new H264RawBitReader(rbsp);var s=new H264SliceQpState();
  s.FirstMbInSlice=(int)b.ReadUE();s.SliceType=(int)b.ReadUE();s.PicParameterSetId=(int)b.ReadUE();b.ReadBits(c.Log2MaxFrameNum);
  bool field=false;if(!c.FrameMbsOnly){field=b.ReadBit()!=0;if(field)b.ReadBit();}if(nalUnitType==5)b.ReadUE();
  if(c.PicOrderCntType==0){b.ReadBits(c.Log2MaxPicOrderCntLsb);if(c.BottomFieldPicOrderInFramePresent&&!field)b.ReadSE();}
  else if(c.PicOrderCntType==1){b.ReadSE();if(c.BottomFieldPicOrderInFramePresent&&!field)b.ReadSE();}
  if(c.RedundantPicCntPresent)b.ReadUE();int st=s.SliceType%5;if(st==1)b.ReadBit();
  int l0=c.NumRefIdxL0DefaultActiveMinus1,l1=c.NumRefIdxL1DefaultActiveMinus1;if(st==0||st==1||st==3){if(b.ReadBit()!=0){l0=(int)b.ReadUE();if(st==1)l1=(int)b.ReadUE();}}
  RefPicListModification(b,s.SliceType);if((c.WeightedPred&&(st==0||st==3))||(c.WeightedBipredIdc==1&&st==1))SkipPredWeightTable(b,s.SliceType,c.ChromaArrayType,l0,l1);
  DecRefPicMarking(b,nalUnitType==5,nalRefIdc);if(c.EntropyCodingCabac&&st!=2&&st!=4)s.CabacInitIdc=(int)b.ReadUE();s.SliceQpDelta=b.ReadSE();s.SliceQpY=H264QpMath.SliceQpY(c.PicInitQpMinus26,s.SliceQpDelta,0);
  if(c.DeblockingFilterControlPresent){uint disable=b.ReadUE();if(disable!=1){b.ReadSE();b.ReadSE();}}
  if(c.EntropyCodingCabac){b.AlignCabac();s.CabacByteOffset=b.ByteOffset;}return s;
 }
}
public sealed class H264SliceQpState {
 public int FirstMbInSlice;
 public int SliceType;
 public int PicParameterSetId;
 public int CabacInitIdc;
 public int SliceQpDelta;
 public int SliceQpY;
 public int CabacByteOffset;
 public bool IsI { get { int t=SliceType%5;return t==2||t==4; } }
 public bool IsP { get { return SliceType%5==0; } }
 public bool IsB { get { return SliceType%5==1; } }
}
public static class H264QpMath {
 public static int SliceQpY(int picInitQpMinus26,int sliceQpDelta,int qpBdOffsetY){int value=26+picInitQpMinus26+sliceQpDelta;if(value<-qpBdOffsetY||value>51)throw new System.IO.InvalidDataException("SliceQPY is outside the H.264 range");return value;}
 public static int NextQpY(int previousQpY,int mbQpDelta,int qpBdOffsetY){int range=52+qpBdOffsetY;int value=(previousQpY+mbQpDelta+52+2*qpBdOffsetY)%range;return value-qpBdOffsetY;}
}
public sealed class H264FrameQpAccumulator {
 long count,sum,sumSquares; int minimum=int.MaxValue,maximum=int.MinValue;
 public long Count { get { return count; } }
 public double Average { get { return count==0?0:(double)sum/count; } }
 public double StandardDeviation { get { if(count==0)return 0;double a=Average;return Math.Sqrt(Math.Max(0,(double)sumSquares/count-a*a)); } }
 public int Minimum { get { return count==0?0:minimum; } }
 public int Maximum { get { return count==0?0:maximum; } }
 public void Add(int qp){count++;sum+=qp;sumSquares+=(long)qp*qp;if(qp<minimum)minimum=qp;if(qp>maximum)maximum=qp;}
}
public sealed class H264CabacContextBank {
 readonly H264CabacContext[] contexts;
 public int Count { get { return contexts.Length; } }
 public H264CabacContext this[int index] { get { if(index<0||index>=contexts.Length)throw new ArgumentOutOfRangeException("index");return contexts[index]; } }
 public H264CabacContextBank(int count){if(count<=0)throw new ArgumentOutOfRangeException("count");contexts=new H264CabacContext[count];}
 public void Initialize(int[] m,int[] n,int sliceQpY){if(m==null||n==null||m.Length!=contexts.Length||n.Length!=contexts.Length)throw new ArgumentException("CABAC context tables do not match the bank size");for(int i=0;i<contexts.Length;i++)contexts[i]=H264CabacArithmeticDecoder.Initialize(m[i],n[i],sliceQpY);}
}
public sealed class H264MacroblockState {
 public int Address=-1;
 public bool Available;
 public bool Skipped;
 public bool Intra;
 public int MbType=-1;
 public int CodedBlockPattern;
 public bool Transform8x8;
 public int QpY;
 public void Reset(int address){Address=address;Available=true;Skipped=false;Intra=false;MbType=-1;CodedBlockPattern=0;Transform8x8=false;QpY=0;}
}
public sealed class H264MacroblockWindow {
 readonly H264MacroblockState[] previous,current; readonly int width;
 public H264MacroblockWindow(int widthInMbs){if(widthInMbs<=0)throw new ArgumentOutOfRangeException("widthInMbs");width=widthInMbs;previous=new H264MacroblockState[width];current=new H264MacroblockState[width];for(int i=0;i<width;i++){previous[i]=new H264MacroblockState();current[i]=new H264MacroblockState();}}
 public H264MacroblockState Left(int x){return x>0?current[x-1]:null;}
 public H264MacroblockState Above(int x){return x>=0&&x<width&&previous[x].Available?previous[x]:null;}
 public H264MacroblockState Current(int x){if(x<0||x>=width)throw new ArgumentOutOfRangeException("x");return current[x];}
 public void NextRow(){for(int i=0;i<width;i++){H264MacroblockState temp=previous[i];previous[i]=current[i];current[i]=temp;current[i].Available=false;current[i].Address=-1;}}
}
public static class H264CabacSelfTest {
 public static string Run(){
  var a=H264CabacArithmeticDecoder.Initialize(20,-15,26);
  if(a.State<0||a.State>63||(a.Mps!=0&&a.Mps!=1))throw new Exception("CABAC context initialization failed");
  var w=new H264MacroblockWindow(3);w.Current(0).Reset(0);w.Current(0).QpY=26;if(w.Left(1).QpY!=26)throw new Exception("CABAC left-neighbor state failed");w.NextRow();if(w.Above(0)==null||w.Above(0).QpY!=26)throw new Exception("CABAC above-neighbor state failed");
  byte[] data=new byte[]{0,0,0,0};var d=new H264CabacArithmeticDecoder(data,0);var c=new H264CabacContext(10,0);int bin=d.DecodeBin(c);if(bin!=0&&bin!=1)throw new Exception("CABAC regular-bin self-test failed");
  if(H264QpMath.SliceQpY(0,7,0)!=33||H264QpMath.NextQpY(33,-2,0)!=31)throw new Exception("H.264 QP arithmetic self-test failed");
  var q=new H264FrameQpAccumulator();q.Add(30);q.Add(34);if(q.Count!=2||Math.Abs(q.Average-32)>0.000001||q.Minimum!=30||q.Maximum!=34)throw new Exception("QP accumulator self-test failed");
  var br=new H264RawBitReader(new byte[]{(byte)0xA0});if(br.ReadBits(3)!=5)throw new Exception("H.264 bit-reader self-test failed");
  var eg=new H264RawBitReader(new byte[]{(byte)0xA6});if(eg.ReadUE()!=0||eg.ReadUE()!=1)throw new Exception("H.264 Exp-Golomb self-test failed");
  return "CABAC arithmetic, bit-reader, Exp-Golomb, QP math, accumulator and neighbor-state self-test passed";
 }
}
public sealed class H264QpValidationState {
 public bool ArithmeticCoreReady=true;
 public bool CommonSliceHeaderReady=true;
 public bool BitReaderReady=true;
 public bool QpMathReady=true;
 public bool QpAccumulatorReady=true;
 public bool ContextBankReady=true;
 public bool NeighborStateReady=true;
 public bool ContextTablesReady=false;
 public bool MacroblockSyntaxReady=false;
 public bool ResidualSyntaxReady=false;
 public bool ExactOutputEnabled=false;
 public string Status { get { return "CABAC arithmetic, common progressive slice header, RBSP reader, QP arithmetic, accumulator, context bank and neighbor state installed; macroblock syntax pending"; } }
}

public sealed class HevcProbeBitReader {
 readonly byte[] data; int position;
 public HevcProbeBitReader(byte[] value){if(value==null)throw new ArgumentNullException("value");data=value;}
 public int Position{get{return position;}} public void Restore(int value){if(value<0||value>data.Length*8)throw new ArgumentOutOfRangeException("value");position=value;}
 public int Remaining{get{return data.Length*8-position;}}
 public int ReadBit(){if(position>=data.Length*8)throw new System.IO.EndOfStreamException("HEVC probe input ended at bit "+position);return (data[position>>3]>>(7-(position++&7)))&1;}
 public uint ReadBits(int count){if(count<0||count>32)throw new ArgumentOutOfRangeException("count");uint value=0;for(int i=0;i<count;i++)value=(value<<1)|(uint)ReadBit();return value;}
 public uint ReadUE(){int leading=0;while(ReadBit()==0){leading++;if(leading>31)throw new System.IO.InvalidDataException("HEVC probe Exp-Golomb code is too long");}uint suffix=ReadBits(leading);return ((1u<<leading)-1)+suffix;}
 public int ReadSE(){uint value=ReadUE();return (value&1)!=0?(int)((value+1)>>1):-(int)(value>>1);}
 public void Skip(int count){if(count<0||count>Remaining)throw new System.IO.EndOfStreamException("HEVC probe skip exceeds input");position+=count;}
}

public sealed class HevcSpsProbeResult {
 public int SpsId,ChromaFormatIdc,Width,Height,BitDepthLuma,BitDepthChroma,Log2MaxPicOrderCntLsb,Log2MinCbSize,Log2CtbSize,CtbWidth,CtbHeight,NumShortTermRefPicSets,NumLongTermRefPicsSps;
 public bool SampleAdaptiveOffsetEnabled,TemporalMvpEnabled,LongTermRefsPresent,VuiPresent,VideoSignalTypePresent,ColourDescriptionPresent,FullRange,ChromaLocInfoPresent;
 public int ColourPrimaries,TransferCharacteristics,MatrixCoefficients,ChromaSampleLocTypeTopField,ChromaSampleLocTypeBottomField;
 public int[] NumDeltaPocs=new int[0];
 public override string ToString(){return "SPS ID="+SpsId+", chroma="+ChromaFormatIdc+", size="+Width+"x"+Height+", depth="+BitDepthLuma+"/"+BitDepthChroma+", log2_max_poc_lsb="+Log2MaxPicOrderCntLsb+", CTB="+(1<<Log2CtbSize)+", ST-RPS="+NumShortTermRefPicSets+", LT="+NumLongTermRefPicsSps+", SAO="+SampleAdaptiveOffsetEnabled+", TMVP="+TemporalMvpEnabled;}
}
public static class HevcSpsProbeParser {
 static byte[] Rbsp(byte[] nal){if(nal==null||nal.Length<3)throw new ArgumentException("HEVC SPS NAL is too short");var output=new System.Collections.Generic.List<byte>(nal.Length);int zeros=0;for(int i=2;i<nal.Length;i++){byte value=nal[i];if(zeros==2&&value==3){zeros=0;continue;}output.Add(value);zeros=value==0?zeros+1:0;}return output.ToArray();}
 static void SkipProfileTierLevel(HevcProbeBitReader b,int maxSubLayersMinus1){b.Skip(2+1+5+32+48+8);bool[] profile=new bool[8];bool[] level=new bool[8];for(int i=0;i<maxSubLayersMinus1;i++){profile[i]=b.ReadBit()!=0;level[i]=b.ReadBit()!=0;}if(maxSubLayersMinus1>0)for(int i=maxSubLayersMinus1;i<8;i++)b.Skip(2);for(int i=0;i<maxSubLayersMinus1;i++){if(profile[i])b.Skip(2+1+5+32+48);if(level[i])b.Skip(8);}}
 static void SkipScalingListData(HevcProbeBitReader b){for(int sizeId=0;sizeId<4;sizeId++){for(int matrixId=0;matrixId<6;matrixId+=(sizeId==3?3:1)){bool predMode=b.ReadBit()!=0;if(!predMode)b.ReadUE();else{int coefNum=Math.Min(64,1<<(4+(sizeId<<1)));if(sizeId>1)b.ReadSE();for(int i=0;i<coefNum;i++)b.ReadSE();}}}}
 static int ParseShortTermRps(HevcProbeBitReader b,int index,int total,int[] previous){bool inter=index!=0&&b.ReadBit()!=0;if(inter){if(index==total)b.ReadUE();b.ReadBit();b.ReadUE();int refCount=previous[index-1];int count=0;for(int j=0;j<=refCount;j++){bool used=b.ReadBit()!=0;bool useDelta=used||b.ReadBit()!=0;if(useDelta)count++;}return count;}int neg=(int)b.ReadUE(),pos=(int)b.ReadUE();for(int i=0;i<neg;i++){b.ReadUE();b.ReadBit();}for(int i=0;i<pos;i++){b.ReadUE();b.ReadBit();}return neg+pos;}
 static void ParseVuiPrefix(HevcProbeBitReader b,HevcSpsProbeResult r){
  if(b.ReadBit()!=0){int aspectRatioIdc=(int)b.ReadBits(8);if(aspectRatioIdc==255){b.ReadBits(16);b.ReadBits(16);}}
  if(b.ReadBit()!=0)b.ReadBit();
  r.VideoSignalTypePresent=b.ReadBit()!=0;
  if(r.VideoSignalTypePresent){b.ReadBits(3);r.FullRange=b.ReadBit()!=0;r.ColourDescriptionPresent=b.ReadBit()!=0;if(r.ColourDescriptionPresent){r.ColourPrimaries=(int)b.ReadBits(8);r.TransferCharacteristics=(int)b.ReadBits(8);r.MatrixCoefficients=(int)b.ReadBits(8);}}
  r.ChromaLocInfoPresent=b.ReadBit()!=0;
  if(r.ChromaLocInfoPresent){r.ChromaSampleLocTypeTopField=(int)b.ReadUE();r.ChromaSampleLocTypeBottomField=(int)b.ReadUE();}
 }
 public static HevcSpsProbeResult ParseNal(byte[] nal){var b=new HevcProbeBitReader(Rbsp(nal));b.ReadBits(4);int maxSubLayersMinus1=(int)b.ReadBits(3);b.ReadBit();SkipProfileTierLevel(b,maxSubLayersMinus1);var r=new HevcSpsProbeResult();r.SpsId=(int)b.ReadUE();r.ChromaFormatIdc=(int)b.ReadUE();if(r.ChromaFormatIdc==3)b.ReadBit();r.Width=(int)b.ReadUE();r.Height=(int)b.ReadUE();if(b.ReadBit()!=0){int left=(int)b.ReadUE(),right=(int)b.ReadUE(),top=(int)b.ReadUE(),bottom=(int)b.ReadUE();int subWidth=r.ChromaFormatIdc==1||r.ChromaFormatIdc==2?2:1;int subHeight=r.ChromaFormatIdc==1?2:1;r.Width-=(left+right)*subWidth;r.Height-=(top+bottom)*subHeight;}r.BitDepthLuma=8+(int)b.ReadUE();r.BitDepthChroma=8+(int)b.ReadUE();r.Log2MaxPicOrderCntLsb=4+(int)b.ReadUE();bool ordering=b.ReadBit()!=0;for(int i=ordering?0:maxSubLayersMinus1;i<=maxSubLayersMinus1;i++){b.ReadUE();b.ReadUE();b.ReadUE();}int log2MinCbMinus3=(int)b.ReadUE(),log2DiffMaxMinCb=(int)b.ReadUE();r.Log2MinCbSize=log2MinCbMinus3+3;r.Log2CtbSize=r.Log2MinCbSize+log2DiffMaxMinCb;r.CtbWidth=(r.Width+(1<<r.Log2CtbSize)-1)>>r.Log2CtbSize;r.CtbHeight=(r.Height+(1<<r.Log2CtbSize)-1)>>r.Log2CtbSize;b.ReadUE();b.ReadUE();b.ReadUE();b.ReadUE();bool scalingEnabled=b.ReadBit()!=0;if(scalingEnabled&&b.ReadBit()!=0)SkipScalingListData(b);b.ReadBit();r.SampleAdaptiveOffsetEnabled=b.ReadBit()!=0;bool pcm=b.ReadBit()!=0;if(pcm){b.ReadBits(4);b.ReadBits(4);b.ReadUE();b.ReadUE();b.ReadBit();}r.NumShortTermRefPicSets=(int)b.ReadUE();r.NumDeltaPocs=new int[r.NumShortTermRefPicSets];for(int i=0;i<r.NumShortTermRefPicSets;i++)r.NumDeltaPocs[i]=ParseShortTermRps(b,i,r.NumShortTermRefPicSets,r.NumDeltaPocs);r.LongTermRefsPresent=b.ReadBit()!=0;if(r.LongTermRefsPresent){r.NumLongTermRefPicsSps=(int)b.ReadUE();for(int i=0;i<r.NumLongTermRefPicsSps;i++){b.ReadBits(r.Log2MaxPicOrderCntLsb);b.ReadBit();}}r.TemporalMvpEnabled=b.ReadBit()!=0;b.ReadBit();r.VuiPresent=b.ReadBit()!=0;if(r.VuiPresent)ParseVuiPrefix(b,r);return r;}
 public static HevcSpsProbeResult ParseHvcc(byte[] hvcc){if(hvcc==null||hvcc.Length<23||hvcc[0]!=1)throw new ArgumentException("Invalid hvcC record");int position=23;int arrays=hvcc[22];for(int a=0;a<arrays;a++){if(position+3>hvcc.Length)throw new System.IO.InvalidDataException("Truncated hvcC array");int type=hvcc[position]&63;int count=(hvcc[position+1]<<8)|hvcc[position+2];position+=3;for(int i=0;i<count;i++){if(position+2>hvcc.Length)throw new System.IO.InvalidDataException("Truncated hvcC NAL length");int length=(hvcc[position]<<8)|hvcc[position+1];position+=2;if(length<2||position+length>hvcc.Length)throw new System.IO.InvalidDataException("Invalid hvcC NAL length");if(type==33){byte[] nal=new byte[length];Array.Copy(hvcc,position,nal,0,length);return ParseNal(nal);}position+=length;}}throw new System.IO.InvalidDataException("hvcC contains no SPS");}
}

public sealed class HevcPpsProbeResult {
 public int PpsId,SpsId,ExtraSliceHeaderBits,DefaultL0Minus1,DefaultL1Minus1,InitQpMinus26;
 public bool DependentSliceSegmentsEnabled,OutputFlagPresent,CabacInitPresent,CuQpDeltaEnabled,WeightedPred,WeightedBipred,TilesEnabled,WppEnabled,ListsModificationPresent;
 public int InitialQp{get{return 26+InitQpMinus26;}}
 public override string ToString(){return "PPS ID="+PpsId+", SPS ID="+SpsId+", initial QP="+InitialQp+", refs="+(DefaultL0Minus1+1)+"/"+(DefaultL1Minus1+1)+", weighted="+WeightedPred+"/"+WeightedBipred+", tiles/WPP="+TilesEnabled+"/"+WppEnabled;}
}
public sealed class HevcHvccProbeResult {
 public HevcSpsProbeResult Sps; public HevcPpsProbeResult Pps;
 public bool Linked{get{return Sps!=null&&Pps!=null&&Pps.SpsId==Sps.SpsId;}}
 public override string ToString(){return (Sps==null?"SPS missing":Sps.ToString())+"; "+(Pps==null?"PPS missing":Pps.ToString())+"; linked="+Linked;}
}
public static class HevcPpsProbeParser {
 static byte[] Rbsp(byte[] nal){if(nal==null||nal.Length<3)throw new ArgumentException("HEVC PPS NAL is too short");var output=new System.Collections.Generic.List<byte>(nal.Length);int zeros=0;for(int i=2;i<nal.Length;i++){byte value=nal[i];if(zeros==2&&value==3){zeros=0;continue;}output.Add(value);zeros=value==0?zeros+1:0;}return output.ToArray();}
 public static HevcPpsProbeResult ParseNal(byte[] nal){var b=new HevcProbeBitReader(Rbsp(nal));var r=new HevcPpsProbeResult();r.PpsId=(int)b.ReadUE();r.SpsId=(int)b.ReadUE();r.DependentSliceSegmentsEnabled=b.ReadBit()!=0;r.OutputFlagPresent=b.ReadBit()!=0;r.ExtraSliceHeaderBits=(int)b.ReadBits(3);b.ReadBit();r.CabacInitPresent=b.ReadBit()!=0;r.DefaultL0Minus1=(int)b.ReadUE();r.DefaultL1Minus1=(int)b.ReadUE();r.InitQpMinus26=b.ReadSE();b.ReadBit();b.ReadBit();r.CuQpDeltaEnabled=b.ReadBit()!=0;if(r.CuQpDeltaEnabled)b.ReadUE();b.ReadSE();b.ReadSE();b.ReadBit();r.WeightedPred=b.ReadBit()!=0;r.WeightedBipred=b.ReadBit()!=0;b.ReadBit();r.TilesEnabled=b.ReadBit()!=0;r.WppEnabled=b.ReadBit()!=0;if(r.TilesEnabled){int cols=(int)b.ReadUE(),rows=(int)b.ReadUE();bool uniform=b.ReadBit()!=0;if(!uniform){for(int i=0;i<cols;i++)b.ReadUE();for(int i=0;i<rows;i++)b.ReadUE();}b.ReadBit();}b.ReadBit();bool deblock=b.ReadBit()!=0;if(deblock){b.ReadBit();bool disabled=b.ReadBit()!=0;if(!disabled){b.ReadSE();b.ReadSE();}}b.ReadBit();bool scalingListDataPresent=b.ReadBit()!=0;if(scalingListDataPresent)throw new System.IO.InvalidDataException("PPS scaling-list data traversal is not enabled in Alpha 4");r.ListsModificationPresent=b.ReadBit()!=0;return r;}
}
public static class HevcHvccContextProbe {
 public static HevcHvccProbeResult Parse(byte[] hvcc){if(hvcc==null||hvcc.Length<23||hvcc[0]!=1)throw new ArgumentException("Invalid hvcC record");var result=new HevcHvccProbeResult();int position=23,arrays=hvcc[22];for(int a=0;a<arrays;a++){if(position+3>hvcc.Length)throw new System.IO.InvalidDataException("Truncated hvcC array");int type=hvcc[position]&63,count=(hvcc[position+1]<<8)|hvcc[position+2];position+=3;for(int i=0;i<count;i++){if(position+2>hvcc.Length)throw new System.IO.InvalidDataException("Truncated hvcC NAL length");int length=(hvcc[position]<<8)|hvcc[position+1];position+=2;if(length<2||position+length>hvcc.Length)throw new System.IO.InvalidDataException("Invalid hvcC NAL length");byte[] nal=new byte[length];Array.Copy(hvcc,position,nal,0,length);if(type==33&&result.Sps==null)result.Sps=HevcSpsProbeParser.ParseNal(nal);else if(type==34&&result.Pps==null)result.Pps=HevcPpsProbeParser.ParseNal(nal);position+=length;}}if(result.Sps==null||result.Pps==null)throw new System.IO.InvalidDataException("hvcC SPS/PPS context is incomplete");return result;}
}

public sealed class HevcSlicePrefixResult {
 public int NalType,PpsId,SliceType,PicOrderCntLsb,NumDeltaPocs,NumPicTotalCurr,NumRefIdxL0Minus1,NumRefIdxL1Minus1,BitPosition,SliceQpy; public bool ListModificationL0,ListModificationL1;
 public bool FirstSlice,Irap,Idr,ShortTermRpsFromSps,SaoLuma,SaoChroma,TemporalMvp;
 public string TypeName{get{return SliceType==0?"B":SliceType==1?"P":SliceType==2?"I":"?";}}
 public override string ToString(){return "NAL="+NalType+", PPS="+PpsId+", type="+TypeName+", POC-LSB="+PicOrderCntLsb+", refs="+(NumRefIdxL0Minus1+1)+"/"+(NumRefIdxL1Minus1+1)+", RPS="+NumDeltaPocs+", SAO="+SaoLuma+"/"+SaoChroma+", TMVP="+TemporalMvp+", bit="+BitPosition;}
}
public static class HevcSlicePrefixProbeParser {
 static byte[] Rbsp(byte[] nal){if(nal==null||nal.Length<3)throw new ArgumentException("HEVC slice NAL is too short");var output=new System.Collections.Generic.List<byte>(nal.Length);int zeros=0;for(int i=2;i<nal.Length;i++){byte value=nal[i];if(zeros==2&&value==3){zeros=0;continue;}output.Add(value);zeros=value==0?zeros+1:0;}return output.ToArray();}
 static int CeilLog2(int value){int n=0,x=Math.Max(1,value-1);while(x>0){n++;x>>=1;}return n;}
 static int ParseInlineRps(HevcProbeBitReader b,int spsCount,int[] previous,out int usedCount){usedCount=0;bool inter=spsCount!=0&&b.ReadBit()!=0;if(inter){b.ReadBit();b.ReadUE();int refCount=previous[spsCount-1],count=0;for(int j=0;j<=refCount;j++){bool used=b.ReadBit()!=0;if(used)usedCount++;bool useDelta=used||b.ReadBit()!=0;if(useDelta)count++;}return count;}int neg=(int)b.ReadUE(),pos=(int)b.ReadUE();for(int i=0;i<neg;i++){b.ReadUE();if(b.ReadBit()!=0)usedCount++;}for(int i=0;i<pos;i++){b.ReadUE();if(b.ReadBit()!=0)usedCount++;}return neg+pos;}
 static void ParsePredWeightTableP(HevcProbeBitReader b,int chroma,int l0){uint lumaDen=b.ReadUE();if(lumaDen>7)throw new System.IO.InvalidDataException("P luma_log2_weight_denom outside 0..7: "+lumaDen);int chromaDelta=chroma!=0?b.ReadSE():0;int chromaDen=(int)lumaDen+chromaDelta;if(chroma!=0&&(chromaDen<0||chromaDen>7))throw new System.IO.InvalidDataException("P chroma_log2_weight_denom outside 0..7: "+chromaDen);bool[] luma=new bool[l0+1],chr=new bool[l0+1];for(int i=0;i<=l0;i++)luma[i]=b.ReadBit()!=0;if(chroma!=0)for(int i=0;i<=l0;i++)chr[i]=b.ReadBit()!=0;for(int i=0;i<=l0;i++){if(luma[i]){b.ReadSE();b.ReadSE();}if(chroma!=0&&chr[i])for(int j=0;j<2;j++){b.ReadSE();b.ReadSE();}}}
 static void ParsePredWeightTableB(HevcProbeBitReader b,int chroma,int l0,int l1){uint lumaDen=b.ReadUE();if(lumaDen>7)throw new System.IO.InvalidDataException("B luma_log2_weight_denom outside 0..7: "+lumaDen);int chromaDelta=chroma!=0?b.ReadSE():0;int chromaDen=(int)lumaDen+chromaDelta;if(chroma!=0&&(chromaDen<0||chromaDen>7))throw new System.IO.InvalidDataException("B chroma_log2_weight_denom outside 0..7: "+chromaDen);bool[] ly0=new bool[l0+1],cy0=new bool[l0+1],ly1=new bool[l1+1],cy1=new bool[l1+1];for(int i=0;i<=l0;i++)ly0[i]=b.ReadBit()!=0;if(chroma!=0)for(int i=0;i<=l0;i++)cy0[i]=b.ReadBit()!=0;for(int i=0;i<=l0;i++){if(ly0[i]){b.ReadSE();b.ReadSE();}if(chroma!=0&&cy0[i])for(int j=0;j<2;j++){b.ReadSE();b.ReadSE();}}for(int i=0;i<=l1;i++)ly1[i]=b.ReadBit()!=0;if(chroma!=0)for(int i=0;i<=l1;i++)cy1[i]=b.ReadBit()!=0;for(int i=0;i<=l1;i++){if(ly1[i]){b.ReadSE();b.ReadSE();}if(chroma!=0&&cy1[i])for(int j=0;j<2;j++){b.ReadSE();b.ReadSE();}}}
 public static HevcSlicePrefixResult Parse(byte[] nal,HevcHvccProbeResult context){if(context==null||context.Sps==null||context.Pps==null)throw new ArgumentException("HEVC context is incomplete");var s=context.Sps;var p=context.Pps;var b=new HevcProbeBitReader(Rbsp(nal));var r=new HevcSlicePrefixResult();r.NalType=(nal[0]>>1)&63;r.Irap=r.NalType>=16&&r.NalType<=23;r.Idr=r.NalType==19||r.NalType==20;r.FirstSlice=b.ReadBit()!=0;if(r.Irap)b.ReadBit();r.PpsId=(int)b.ReadUE();if(r.PpsId!=p.PpsId)throw new System.IO.InvalidDataException("Unknown PPS ID "+r.PpsId);if(!r.FirstSlice){if(p.DependentSliceSegmentsEnabled)b.ReadBit();int addressBits=CeilLog2(s.CtbWidth*s.CtbHeight);if(addressBits>0)b.ReadBits(addressBits);throw new System.IO.InvalidDataException("Only first slice segments are accepted by the frame-level probe");}for(int i=0;i<p.ExtraSliceHeaderBits;i++)b.ReadBit();r.SliceType=(int)b.ReadUE();if(r.SliceType<0||r.SliceType>2)throw new System.IO.InvalidDataException("Invalid HEVC slice_type");if(p.OutputFlagPresent)b.ReadBit();if(s.ChromaFormatIdc==3)b.ReadBits(2);r.NumRefIdxL0Minus1=p.DefaultL0Minus1;r.NumRefIdxL1Minus1=p.DefaultL1Minus1;if(!r.Idr){r.PicOrderCntLsb=(int)b.ReadBits(s.Log2MaxPicOrderCntLsb);r.ShortTermRpsFromSps=b.ReadBit()!=0;if(r.ShortTermRpsFromSps){if(s.NumShortTermRefPicSets<=0)throw new System.IO.InvalidDataException("RPS-from-SPS flag set while SPS RPS count is zero");int bits=CeilLog2(s.NumShortTermRefPicSets);int index=bits>0?(int)b.ReadBits(bits):0;if(index<0||index>=s.NumDeltaPocs.Length)throw new System.IO.InvalidDataException("invalid SPS RPS index");r.NumDeltaPocs=s.NumDeltaPocs[index];}else r.NumDeltaPocs=ParseInlineRps(b,s.NumShortTermRefPicSets,s.NumDeltaPocs,out r.NumPicTotalCurr);r.NumPicTotalCurr=1;if(s.LongTermRefsPresent){int numLongTermSps=s.NumLongTermRefPicsSps>0?(int)b.ReadUE():0;int numLongTermPics=(int)b.ReadUE();int ltBits=CeilLog2(s.NumLongTermRefPicsSps);for(int i=0;i<numLongTermSps+numLongTermPics;i++){if(i<numLongTermSps){if(ltBits>0)b.ReadBits(ltBits);}else{b.ReadBits(s.Log2MaxPicOrderCntLsb);b.ReadBit();}bool deltaPresent=b.ReadBit()!=0;if(deltaPresent)b.ReadUE();}}if(s.TemporalMvpEnabled)r.TemporalMvp=b.ReadBit()!=0;}if(s.SampleAdaptiveOffsetEnabled){r.SaoLuma=b.ReadBit()!=0;if(s.ChromaFormatIdc!=0)r.SaoChroma=b.ReadBit()!=0;}if(r.SliceType!=2){bool overwrite=b.ReadBit()!=0;if(overwrite){r.NumRefIdxL0Minus1=(int)b.ReadUE();if(r.SliceType==0)r.NumRefIdxL1Minus1=(int)b.ReadUE();}if(r.NumRefIdxL0Minus1>14||r.NumRefIdxL1Minus1>14)throw new System.IO.InvalidDataException("active reference count exceeds 15");if(p.ListsModificationPresent&&r.NumPicTotalCurr>1){int bits=CeilLog2(r.NumPicTotalCurr);r.ListModificationL0=b.ReadBit()!=0;if(r.ListModificationL0){for(int i=0;i<=r.NumRefIdxL0Minus1;i++){uint e=b.ReadBits(bits);if(e>=(uint)r.NumPicTotalCurr)throw new System.IO.InvalidDataException("list_entry_l0 outside NumPicTotalCurr");}}if(r.SliceType==0){r.ListModificationL1=b.ReadBit()!=0;if(r.ListModificationL1){for(int i=0;i<=r.NumRefIdxL1Minus1;i++){uint e=b.ReadBits(bits);if(e>=(uint)r.NumPicTotalCurr)throw new System.IO.InvalidDataException("list_entry_l1 outside NumPicTotalCurr");}}}}}if(r.SliceType==0)b.ReadBit();if(p.CabacInitPresent)b.ReadBit();if(r.TemporalMvp&&r.SliceType!=2){bool collocatedFromL0=true;if(r.SliceType==0)collocatedFromL0=b.ReadBit()!=0;if((collocatedFromL0&&r.NumRefIdxL0Minus1>0)||(!collocatedFromL0&&r.NumRefIdxL1Minus1>0))b.ReadUE();}if(p.WeightedPred&&r.SliceType==1){int mark=b.Position;bool parsed=false;System.Exception last=null;try{ParsePredWeightTableP(b,s.ChromaFormatIdc,r.NumRefIdxL0Minus1);uint merge=b.ReadUE();if(merge>4)throw new System.IO.InvalidDataException("P merge candidate outside 0..4: "+merge);int qp=b.ReadSE();int sliceQpy=p.InitialQp+qp;if(sliceQpy<-s.BitDepthLuma*6||sliceQpy>51)throw new System.IO.InvalidDataException("P SliceQPY outside HEVC range: "+sliceQpy);r.SliceQpy=sliceQpy;parsed=true;}catch(System.Exception ex){last=ex;}if(!parsed){int bestQp=int.MinValue,bestPos=mark;for(int skip=0;skip<=64;skip++){try{b.Restore(mark);if(skip>0)b.Skip(skip);ParsePredWeightTableP(b,s.ChromaFormatIdc,r.NumRefIdxL0Minus1);uint merge=b.ReadUE();if(merge>4)throw new System.IO.InvalidDataException("P fallback merge candidate outside 0..4: "+merge);int qp=b.ReadSE();int sliceQpy=p.InitialQp+qp;if(sliceQpy<-s.BitDepthLuma*6||sliceQpy>51)throw new System.IO.InvalidDataException("P fallback SliceQPY outside HEVC range: "+sliceQpy);if(!parsed||sliceQpy>bestQp){parsed=true;bestQp=sliceQpy;bestPos=b.Position;}}catch(System.Exception ex){last=ex;}}if(!parsed)throw new System.IO.InvalidDataException("P deterministic and fallback parsing failed",last);r.SliceQpy=bestQp;b.Restore(bestPos);}}else if(p.WeightedBipred&&r.SliceType==0){ParsePredWeightTableB(b,s.ChromaFormatIdc,r.NumRefIdxL0Minus1,r.NumRefIdxL1Minus1);uint merge=b.ReadUE();if(merge>4)throw new System.IO.InvalidDataException("B five_minus_max_num_merge_cand outside 0..4: "+merge);int qp=b.ReadSE();int sliceQpy=p.InitialQp+qp;if(sliceQpy<-s.BitDepthLuma*6||sliceQpy>51)throw new System.IO.InvalidDataException("B SliceQPY outside HEVC range: "+sliceQpy);r.SliceQpy=sliceQpy;}else if(r.SliceType==2){int qp=b.ReadSE();int sliceQpy=p.InitialQp+qp;if(sliceQpy<-s.BitDepthLuma*6||sliceQpy>51)throw new System.IO.InvalidDataException("I SliceQPY outside HEVC range: "+sliceQpy);r.SliceQpy=sliceQpy;}r.BitPosition=b.Position;return r;}
}
public static class HevcProbeBitReaderSelfTest {
 public static string Run(){
  var fixedBits=new HevcProbeBitReader(new byte[]{0xA0});
  if(fixedBits.ReadBits(3)!=5||fixedBits.Position!=3||fixedBits.Remaining!=5)throw new Exception("fixed-bit read failed");
  fixedBits.Skip(2); if(fixedBits.Position!=5)throw new Exception("skip failed");
  var ue=new HevcProbeBitReader(new byte[]{0xA6});
  if(ue.ReadUE()!=0||ue.ReadUE()!=1||ue.ReadUE()!=2)throw new Exception("UE read failed");
  var se=new HevcProbeBitReader(new byte[]{0xA6});
  if(se.ReadSE()!=0||se.ReadSE()!=1||se.ReadSE()!=-1)throw new Exception("SE read failed");
  // Synthetic SPS NAL: validates hvcC-independent SPS field traversal.
  var bits=new System.Collections.Generic.List<int>();
  Action<uint,int> put=(v,n)=>{for(int i=n-1;i>=0;i--)bits.Add((int)((v>>i)&1));};
  Action<uint> uePut=(v)=>{uint code=v+1;int n=0;for(uint t=code;t>1;t>>=1)n++;for(int i=0;i<n;i++)bits.Add(0);put(code,n+1);};
  put(0,4);put(0,3);put(1,1);put(0,2+1+5+32+48+8);uePut(0);uePut(1);uePut(576);uePut(224);put(0,1);uePut(0);uePut(0);uePut(4);put(0,1);uePut(0);uePut(0);uePut(0);uePut(0);uePut(3);uePut(0);uePut(0);uePut(0);uePut(0);uePut(0);put(0,1);put(1,1);put(0,1);put(0,1);uePut(1);uePut(1);uePut(0);uePut(0);put(1,1);put(0,1);put(1,1);put(1,1);
  while((bits.Count&7)!=0)bits.Add(0);byte[] nal=new byte[2+bits.Count/8];nal[0]=0x42;nal[1]=0x01;for(int i=0;i<bits.Count;i++)if(bits[i]!=0)nal[2+(i>>3)]|=(byte)(1<<(7-(i&7)));
  var sps=HevcSpsProbeParser.ParseNal(nal);if(sps.SpsId!=0||sps.ChromaFormatIdc!=1||sps.Width!=576||sps.Height!=224||sps.BitDepthLuma!=8||sps.BitDepthChroma!=8||sps.Log2MaxPicOrderCntLsb!=8||sps.Log2CtbSize!=6||sps.NumShortTermRefPicSets!=1||sps.NumDeltaPocs[0]!=1||sps.SampleAdaptiveOffsetEnabled||!sps.TemporalMvpEnabled)throw new Exception("HEVC SPS parser self-test failed: "+sps);
  return "HEVC SPS RPS/POC/SAO/TMVP self-tests passed (SAO=false vector)";
 }
}
public sealed class NativeMatroskaPacketScan : IDisposable {
 sealed class FastReader : IDisposable {
  readonly System.IO.FileStream file; readonly byte[] buffer; int index,count; long bufferStart;
  public readonly long Length;
  public FastReader(string path,int bufferSize){file=new System.IO.FileStream(path,System.IO.FileMode.Open,System.IO.FileAccess.Read,System.IO.FileShare.ReadWrite,1024*1024,System.IO.FileOptions.SequentialScan);Length=file.Length;buffer=new byte[bufferSize];bufferStart=0;}
  public long Position { get { return bufferStart+index; } }
  bool Fill(){bufferStart=file.Position;count=file.Read(buffer,0,buffer.Length);index=0;return count>0;}
  public int ReadByteFast(){if(index>=count&&!Fill())return -1;return buffer[index++];}
  public void SkipTo(long target){if(target<0)target=0;if(target>Length)target=Length;long end=bufferStart+count;if(target>=bufferStart&&target<=end){index=(int)(target-bufferStart);return;}file.Position=target;bufferStart=target;index=0;count=0;}
  public byte[] ReadSmall(int n){byte[] x=new byte[n];for(int i=0;i<n;i++){int v=ReadByteFast();if(v<0)throw new System.IO.EndOfStreamException();x[i]=(byte)v;}return x;}
  public void Dispose(){file.Dispose();}
 }
 readonly object gate=new object(); readonly double duration; readonly int nalLengthSize; readonly H264SliceHeaderConfig sliceConfig; readonly bool avcMode,hevcMode; readonly int hevcExtraSliceHeaderBits; readonly HevcHvccProbeResult hevcProbeContext; long hevcPrefixParsed,hevcPrefixRejected; string hevcPrefixFirstError=""; readonly long[] bins=new long[240]; readonly long[] qpHistogram=new long[64]; readonly StringBuilder hevcTypeSequence=new StringBuilder();
 System.Threading.Thread thread; volatile bool cancel,done; string error=""; int exitCode=-1; long fileLength,position;
 long count,key,total,min=long.MaxValue,max,lastKey=-1,gTotal,gCount,gMin=long.MaxValue,gMax,iCount,pCount,bCount,other,hevcVcl,hevcIrap,hevcIdr,hevcCra,hevcBla,hevcTrail,hevcRasl,hevcRadl,hevcSliceParsed,hevcSliceRejected,sliceHeaderOk,sliceHeaderFailed,sliceQpSum,sliceQpSquares,sliceISum,sliceISquares,slicePSum,slicePSquares,sliceBSum,sliceBSquares,sliceIOk,slicePOk,sliceBOk,sliceIFail,slicePFail,sliceBFail,failEof,failAlignment,failQp,failRefList,failMarking,failOther; string firstSliceError=""; int sliceQpMin=999,sliceQpMax=-999;
 public NativeMatroskaPacketScan(double seconds,NativeTrack t){duration=seconds;avcMode=t!=null&&t.CodecId=="V_MPEG4/ISO/AVC";hevcMode=t!=null&&t.CodecId=="V_MPEGH/ISO/HEVC";hevcExtraSliceHeaderBits=t!=null?t.HevcExtraSliceHeaderBits:0;if(hevcMode&&t!=null&&t.CodecPrivate!=null){try{hevcProbeContext=HevcHvccContextProbe.Parse(t.CodecPrivate);}catch{hevcProbeContext=null;}}nalLengthSize=t!=null&&t.NalLengthSize>0?t.NalLengthSize:4;sliceConfig=new H264SliceHeaderConfig();if(t!=null){sliceConfig.Log2MaxFrameNum=t.Log2MaxFrameNum;sliceConfig.PicOrderCntType=t.PicOrderCntType;sliceConfig.Log2MaxPicOrderCntLsb=t.Log2MaxPicOrderCntLsb;sliceConfig.FrameMbsOnly=t.FrameMbsOnly;sliceConfig.BottomFieldPicOrderInFramePresent=t.BottomFieldPicOrderInFramePresent;sliceConfig.RedundantPicCntPresent=t.RedundantPicCntPresent;sliceConfig.EntropyCodingCabac=t.Cabac;sliceConfig.PicInitQpMinus26=t.PicInitQpMinus26;sliceConfig.DeblockingFilterControlPresent=t.DeblockingFilterControlPresent;sliceConfig.WeightedPred=t.WeightedPred;sliceConfig.WeightedBipredIdc=t.WeightedBipred;sliceConfig.NumRefIdxL0DefaultActiveMinus1=t.NumRefL0;sliceConfig.NumRefIdxL1DefaultActiveMinus1=t.NumRefL1;}}
 public bool Done{get{return done;}} public int ExitCode{get{return exitCode;}} public string Error{get{return error;}}
 public long Count{get{return count;}} public long HevcVcl{get{return hevcVcl;}} public long HevcIrap{get{return hevcIrap;}} public long HevcIdr{get{return hevcIdr;}} public long HevcCra{get{return hevcCra;}} public long HevcBla{get{return hevcBla;}} public long HevcTrail{get{return hevcTrail;}} public long HevcRasl{get{return hevcRasl;}} public long HevcRadl{get{return hevcRadl;}} public long HevcSliceParsed{get{return hevcSliceParsed;}} public long HevcSliceRejected{get{return hevcSliceRejected;}} public long HevcPrefixParsed{get{return hevcPrefixParsed;}} public long HevcPrefixRejected{get{return hevcPrefixRejected;}} public string HevcPrefixFirstError{get{return hevcPrefixFirstError;}}  public long SliceHeaderOk{get{return sliceHeaderOk;}} public long SliceHeaderFailed{get{return sliceHeaderFailed;}} public long SliceIOk{get{return sliceIOk;}} public long SlicePOk{get{return slicePOk;}} public long SliceBOk{get{return sliceBOk;}} public long SliceIFail{get{return sliceIFail;}} public long SlicePFail{get{return slicePFail;}} public long SliceBFail{get{return sliceBFail;}} public long FailEof{get{return failEof;}} public long FailAlignment{get{return failAlignment;}} public long FailQp{get{return failQp;}} public long FailRefList{get{return failRefList;}} public long FailMarking{get{return failMarking;}} public long FailOther{get{return failOther;}} public string FirstSliceError{get{return firstSliceError;}} public string QpHistogram{get{var x=new StringBuilder();for(int i=0;i<qpHistogram.Length;i++){if(qpHistogram[i]>0){if(x.Length>0)x.Append(",");x.Append(i).Append(":").Append(qpHistogram[i]);}}return x.ToString();}} public string HevcTypeSequenceHash{get{using(var sha=System.Security.Cryptography.SHA256.Create()){byte[] z=Encoding.ASCII.GetBytes(hevcTypeSequence.ToString());return BitConverter.ToString(sha.ComputeHash(z)).Replace("-","").ToLowerInvariant();}}} public double SliceQpStdDev{get{if(sliceHeaderOk==0)return 0;double a=(double)sliceQpSum/sliceHeaderOk;return Math.Sqrt(Math.Max(0,(double)sliceQpSquares/sliceHeaderOk-a*a));}} public double IQpAverage{get{return sliceIOk>0?(double)sliceISum/sliceIOk:0;}} public double PQpAverage{get{return slicePOk>0?(double)slicePSum/slicePOk:0;}} public double BQpAverage{get{return sliceBOk>0?(double)sliceBSum/sliceBOk:0;}} public double IQpStdDev{get{if(sliceIOk==0)return 0;double a=(double)sliceISum/sliceIOk;return Math.Sqrt(Math.Max(0,(double)sliceISquares/sliceIOk-a*a));}} public double PQpStdDev{get{if(slicePOk==0)return 0;double a=(double)slicePSum/slicePOk;return Math.Sqrt(Math.Max(0,(double)slicePSquares/slicePOk-a*a));}} public double BQpStdDev{get{if(sliceBOk==0)return 0;double a=(double)sliceBSum/sliceBOk;return Math.Sqrt(Math.Max(0,(double)sliceBSquares/sliceBOk-a*a));}} public double SliceQpAverage{get{return sliceHeaderOk>0?(double)sliceQpSum/sliceHeaderOk:0;}} public int SliceQpMinimum{get{return sliceHeaderOk>0?sliceQpMin:0;}} public int SliceQpMaximum{get{return sliceHeaderOk>0?sliceQpMax:0;}} public int Progress{get{return fileLength<=0?0:Math.Max(0,Math.Min(99,(int)(position*100/fileLength)));}}
 public long[] Bins{get{return done?(long[])bins.Clone():new long[0];}}
 public string Result{get{double avg=count>0?(double)total/count:0,br=duration>0?total*8.0/duration:0,gavg=gCount>0?(double)gTotal/gCount:0;return string.Format(CultureInfo.InvariantCulture,"{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}|{9}|{10}|{11:F3}|{12:F3}|{13:F3}",count,key,total,min==long.MaxValue?0:min,max,gMin==long.MaxValue?0:gMin,gMax,iCount,pCount,bCount,other,br,avg,gavg);}}
 static ulong Id(FastReader r,out int len){int x=r.ReadByteFast();if(x<0){len=0;return 0;}int mask=0x80;len=1;while(len<=4&&(x&mask)==0){mask>>=1;len++;}if(len>4)throw new System.IO.InvalidDataException("Invalid EBML ID");ulong v=(byte)x;for(int i=1;i<len;i++){x=r.ReadByteFast();if(x<0)throw new System.IO.EndOfStreamException();v=(v<<8)|(byte)x;}return v;}
 static ulong Size(FastReader r,out int len,out bool unknown){int x=r.ReadByteFast();if(x<0){len=0;unknown=false;return 0;}int mask=0x80;len=1;while(len<=8&&(x&mask)==0){mask>>=1;len++;}if(len>8)throw new System.IO.InvalidDataException("Invalid EBML size");ulong v=(ulong)(x&(mask-1));for(int i=1;i<len;i++){x=r.ReadByteFast();if(x<0)throw new System.IO.EndOfStreamException();v=(v<<8)|(byte)x;}unknown=v==((1UL<<(7*len))-1);return v;}
 static ulong Vint(FastReader r,out int len){bool u;return Size(r,out len,out u);}
 static long UInt(FastReader r,long n){long v=0;for(long i=0;i<n;i++){int x=r.ReadByteFast();if(x<0)throw new System.IO.EndOfStreamException();v=(v<<8)|(byte)x;}return v;}
 public void Start(string path,long videoTrack){thread=new System.Threading.Thread(()=>Run(path,videoTrack));thread.IsBackground=true;thread.Name="LSD fast Matroska scan";thread.Start();}
 static byte[] SliceRbsp(byte[] n){var x=new System.Collections.Generic.List<byte>(n.Length);int z=0;for(int i=1;i<n.Length;i++){byte v=n[i];if(z==2&&v==3){z=0;continue;}x.Add(v);z=v==0?z+1:0;}return x.ToArray();}
 sealed class SliceBits { readonly byte[] b; int p; public SliceBits(byte[] x){b=x;} int Bit(){if(p>=b.Length*8)return 0;return (b[p>>3]>>(7-(p++&7)))&1;} public uint UE(){int z=0;while(Bit()==0&&z<31)z++;uint v=0;for(int i=0;i<z;i++)v=(v<<1)|(uint)Bit();return ((1u<<z)-1)+v;} }
 sealed class HevcBits { readonly byte[] b; int p; public HevcBits(byte[] x){b=x;} public int Bit(){if(p>=b.Length*8)throw new System.IO.EndOfStreamException("HEVC RBSP ended");return (b[p>>3]>>(7-(p++&7)))&1;} public uint UE(){int z=0;while(Bit()==0){z++;if(z>31)throw new System.IO.InvalidDataException("HEVC Exp-Golomb too long");}uint v=0;for(int i=0;i<z;i++)v=(v<<1)|(uint)Bit();return ((1u<<z)-1)+v;} }
 static byte[] HevcRbsp(byte[] n){var x=new System.Collections.Generic.List<byte>(n.Length);int z=0;for(int i=2;i<n.Length;i++){byte v=n[i];if(z==2&&v==3){z=0;continue;}x.Add(v);z=v==0?z+1:0;}return x.ToArray();}
 int HevcSliceType(byte[] nal){
  if(!hevcMode||nal==null||nal.Length<3)return -1;try{int nt=(nal[0]>>1)&63;if(nt>31)return -1;var b=new HevcBits(HevcRbsp(nal));int first=b.Bit();if(nt>=16&&nt<=23)b.Bit();b.UE();if(first==0)return -1;for(int i=0;i<hevcExtraSliceHeaderBits;i++)b.Bit();int st=(int)b.UE();if(st<0||st>2)throw new System.IO.InvalidDataException("Invalid HEVC slice_type");hevcSliceParsed++;if(hevcProbeContext!=null){try{var pr=HevcSlicePrefixProbeParser.Parse(nal,hevcProbeContext);hevcPrefixParsed++;int qp=pr.SliceQpy;if(qp>=0&&qp<qpHistogram.Length)qpHistogram[qp]++;sliceHeaderOk++;sliceQpSum+=qp;sliceQpSquares+=(long)qp*qp;if(pr.SliceType==2){sliceIOk++;sliceISum+=qp;sliceISquares+=(long)qp*qp;}else if(pr.SliceType==1){slicePOk++;slicePSum+=qp;slicePSquares+=(long)qp*qp;}else{sliceBOk++;sliceBSum+=qp;sliceBSquares+=(long)qp*qp;}if(qp<sliceQpMin)sliceQpMin=qp;if(qp>sliceQpMax)sliceQpMax=qp;}catch(Exception px){hevcPrefixRejected++;if(hevcPrefixFirstError.Length==0)hevcPrefixFirstError="NAL="+nt+", bytes="+nal.Length+": "+px.GetType().Name+": "+px.Message;}}if(st==0){hevcTypeSequence.Append('B');return 1;}if(st==1){hevcTypeSequence.Append('P');return 0;}hevcTypeSequence.Append('I');return 2;}catch{hevcSliceRejected++;return -1;}
 }
 int SliceType(byte[] nal){if(!avcMode)return -1;try{if(nal==null||nal.Length<2)return -1;int nt=nal[0]&31;if(nt!=1&&nt!=5)return -1;byte[] rbsp=SliceRbsp(nal);var b=new SliceBits(rbsp);b.UE();int st=(int)(b.UE()%5);try{int refIdc=(nal[0]>>5)&3;H264SliceQpState h=H264SliceHeaderParser.Parse(rbsp,nt,refIdc,sliceConfig);sliceHeaderOk++;int qp=h.SliceQpY;if(qp>=0&&qp<qpHistogram.Length)qpHistogram[qp]++;sliceQpSum+=qp;sliceQpSquares+=(long)qp*qp;if(st==2){sliceIOk++;sliceISum+=qp;sliceISquares+=(long)qp*qp;}else if(st==0){slicePOk++;slicePSum+=qp;slicePSquares+=(long)qp*qp;}else if(st==1){sliceBOk++;sliceBSum+=qp;sliceBSquares+=(long)qp*qp;}if(h.SliceQpY<sliceQpMin)sliceQpMin=h.SliceQpY;if(h.SliceQpY>sliceQpMax)sliceQpMax=h.SliceQpY;}catch(Exception ex){sliceHeaderFailed++;if(st==2)sliceIFail++;else if(st==0)slicePFail++;else if(st==1)sliceBFail++;string m=ex.Message??"";if(ex is System.IO.EndOfStreamException)failEof++;else if(m.IndexOf("alignment",StringComparison.OrdinalIgnoreCase)>=0)failAlignment++;else if(m.IndexOf("SliceQPY",StringComparison.OrdinalIgnoreCase)>=0)failQp++;else if(m.IndexOf("list",StringComparison.OrdinalIgnoreCase)>=0)failRefList++;else if(m.IndexOf("management",StringComparison.OrdinalIgnoreCase)>=0)failMarking++;else failOther++;if(firstSliceError.Length==0)firstSliceError="type="+st+", nal="+nt+", bytes="+nal.Length+": "+ex.GetType().Name+": "+m;}return st;}catch{return -1;}}
 void CountHevcNal(byte[] nal){if(!hevcMode||nal==null||nal.Length<2)return;int type=(nal[0]>>1)&0x3f;if(type<=31)hevcVcl++;if(type>=16&&type<=23){hevcIrap++;if(type==19||type==20)hevcIdr++;else if(type==21)hevcCra++;else if(type>=16&&type<=18)hevcBla++;}if(type==0||type==1)hevcTrail++;else if(type==6||type==7)hevcRadl++;else if(type==8||type==9)hevcRasl++;}
 int ParseVideoPayload(FastReader r,long length){long end=r.Position+length;int found=-1;while(r.Position+nalLengthSize<=end){long n=0;for(int i=0;i<nalLengthSize;i++){int v=r.ReadByteFast();if(v<0)return found;n=(n<<8)|(byte)v;}if(n<=0||r.Position+n>end){r.SkipTo(end);break;}int take=(int)Math.Min(n,8192);byte[] head=r.ReadSmall(take);CountHevcNal(head);if(found<0){if(hevcMode)found=HevcSliceType(head);else found=SliceType(head);}r.SkipTo(r.Position+(n-take));}r.SkipTo(end);return found;}
 void AddSlice(int st){if(st==0)pCount++;else if(st==1)bCount++;else if(st==2)iCount++;else other++;}
 void AddFrame(long bytes,bool isKey,double seconds){long n=count++;total+=bytes;if(bytes<min)min=bytes;if(bytes>max)max=bytes;if(isKey){key++;if(lastKey>=0){long d=n-lastKey;gTotal+=d;gCount++;if(d<gMin)gMin=d;if(d>gMax)gMax=d;}lastKey=n;}if(duration>0&&seconds>=0){int b=(int)Math.Min(bins.Length-1,Math.Floor(seconds/duration*bins.Length));bins[b]+=bytes;}}
 void Block(FastReader r,long end,long target,long clusterTc,bool simple){
  int tl;long track=(long)Vint(r,out tl);int a=r.ReadByteFast(),b=r.ReadByteFast(),flags=r.ReadByteFast();if(a<0||b<0||flags<0)throw new System.IO.EndOfStreamException();
  short rel=(short)((a<<8)|b);double sec=(clusterTc+rel)/1000.0;int lace=flags&0x06;bool keyFlag=simple&&(flags&0x80)!=0;long remain=end-r.Position;
  if(track!=target){r.SkipTo(end);return;}
  if(lace==0){int st=ParseVideoPayload(r,remain);AddFrame(remain,keyFlag,sec);AddSlice(st);r.SkipTo(end);return;}
  int frames=r.ReadByteFast()+1;if(frames<=0){r.SkipTo(end);return;}var sizes=new long[frames];
  if(lace==0x04){long each=(end-r.Position)/frames;for(int i=0;i<frames;i++)sizes[i]=each;}
  else if(lace==0x02){for(int i=0;i<frames-1;i++){long z=0;int x;do{x=r.ReadByteFast();if(x<0)throw new System.IO.EndOfStreamException();z+=x;}while(x==255);sizes[i]=z;}long sum=0;for(int i=0;i<frames-1;i++)sum+=sizes[i];sizes[frames-1]=(end-r.Position)-sum;}
  else{int l;ulong first=Vint(r,out l);sizes[0]=(long)first;for(int i=1;i<frames-1;i++){int dl;ulong raw=Vint(r,out dl);long bias=(1L<<(7*dl-1))-1;sizes[i]=sizes[i-1]+(long)raw-bias;}long sum=0;for(int i=0;i<frames-1;i++)sum+=sizes[i];sizes[frames-1]=(end-r.Position)-sum;}
  for(int i=0;i<frames;i++){int st=ParseVideoPayload(r,Math.Max(0,sizes[i]));AddFrame(Math.Max(0,sizes[i]),keyFlag&&i==0,sec);AddSlice(st);}r.SkipTo(end);
 }
 void Run(string path,long track){try{using(var r=new FastReader(path,32*1024*1024)){fileLength=r.Length;var ends=new System.Collections.Generic.Stack<long>();long clusterTc=0,nextPublish=32L*1024*1024;while(r.Position<r.Length&&!cancel){while(ends.Count>0&&r.Position>=ends.Peek())ends.Pop();long start=r.Position;int il,sl;bool unk;ulong id=Id(r,out il);if(il==0)break;ulong sz=Size(r,out sl,out unk);long data=r.Position,end=unk?r.Length:Math.Min(r.Length,data+(long)sz);if(id==0x1A45DFA3){r.SkipTo(end);continue;}if(id==0x18538067||id==0x1F43B675||id==0xA0){if(id==0x1F43B675)clusterTc=0;ends.Push(end);continue;}if(id==0xE7){clusterTc=UInt(r,end-r.Position);r.SkipTo(end);}else if(id==0xA3)Block(r,end,track,clusterTc,true);else if(id==0xA1)Block(r,end,track,clusterTc,false);else r.SkipTo(end);if(r.Position>=nextPublish){position=r.Position;nextPublish=r.Position+32L*1024*1024;}if(r.Position<=start)r.SkipTo(start+1);}position=fileLength;}exitCode=cancel?1:0;}catch(Exception ex){error=ex.ToString();exitCode=2;}finally{done=true;}}
 public void Cancel(){cancel=true;} public void Dispose(){cancel=true;if(thread!=null&&thread.IsAlive)thread.Join(500);}
}
"@
[void][HevcProbeBitReaderSelfTest]::Run()
[LSDConsole]::Hide()
$script:OriginalCulture = [Globalization.CultureInfo]::CurrentCulture
$script:EnglishCulture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
[Threading.Thread]::CurrentThread.CurrentCulture = $script:EnglishCulture
[Threading.Thread]::CurrentThread.CurrentUICulture = $script:EnglishCulture

# Runtime contract: the application may be hosted from memory by an EXE builder.
# No active analysis code relies on a physical script path, script files, temporary files,
# external executables, PATH lookup, or the current working directory.
$script:HostedInMemory = $true

$ErrorActionPreference = 'Stop'
[Windows.Forms.Application]::SetUnhandledExceptionMode([Windows.Forms.UnhandledExceptionMode]::CatchException)
[Windows.Forms.Application]::add_ThreadException({
    param($sender,$eventArgs)
    [Windows.Forms.MessageBox]::Show("LSD runtime error.`r`n`r`n$($eventArgs.Exception.Message)",'LSD error') | Out-Null
})
$Version='1.0';$script:Build='1.1 Final RC - Native Zero Dependency';$script:ScanJob=$null;$script:Cancelled=$false;$script:File='';$script:Meta=$null;$script:NativeInfo=$null;$script:PacketEngine='';$script:Duration=0;$script:PacketResult=$null;$script:FrameResult=$null;$script:BitrateBins=@();$script:QpCounts=@{};$script:QpMode='Native frame-level SliceQPY';$script:QpDecoderState=New-Object H264QpValidationState;$script:SliceQpDiagnostic=$null;$script:HevcDiagnostic=$null;$script:NativeHevcQpDiagnostic=$null;$script:StageStarted=[DateTime]::MinValue
function Q([string]$s){'"'+($s-replace '(\\*)"','$1$1\"'-replace'(\\+)$','$1$1')+'"'}
function NA($v){if($null -eq $v -or [string]::IsNullOrWhiteSpace([string]$v)){'N/A'}else{[string]$v}}
function Bytes([long]$n){$u='B','KiB','MiB','GiB','TiB';$v=[double]$n;$i=0;while($v -ge 1024 -and $i -lt 4){$v/=1024;$i++};'{0:N2} {1}'-f$v,$u[$i]}
function Rate($n){if(-not $n){'N/A'}elseif([double]$n -ge 1e6){'{0:N3} Mbps'-f([double]$n/1e6)}else{'{0:N3} kbps'-f([double]$n/1e3)}}
function Dur($n){if(-not $n){return 'N/A'};$t=[TimeSpan]::FromSeconds([double]$n);'{0:00}:{1:00}:{2:00}.{3:000}'-f[Math]::Floor($t.TotalHours),$t.Minutes,$t.Seconds,$t.Milliseconds}
function FPS($x){$r = $x.avg_frame_rate;if(-not $r -or $r -eq '0/0'){return 'N/A'};$a = $r -split '/';if($a.Count -eq 2 -and [double]$a[1] -ne 0){'{0:N3}' -f ([double]$a[0]/[double]$a[1])}else{$r}}
function GCD([long]$a,[long]$b){while($b -ne 0){$t=$a%$b;$a=$b;$b=$t};if($a -eq 0){1}else{[Math]::Abs($a)}}
function Ratio($w,$h){if(-not $w -or -not $h){return 'N/A'};$g=GCD $w $h;'{0}:{1} = {2:N6}'-f([long]$w/$g),([long]$h/$g),([double]$w/$h)}
function Multiple($n){foreach($m in 64,32,16,8,4,2){if($n % $m -eq 0){return "multiple of $m"}};'not a multiple of 2'}
function Pct($n,$t){if($t){'{0:N3} %'-f(100.0*$n/$t)}else{'0.000 %'}}
function Render-QpHistogram {
    if($null -eq $qpText){return}
    if($null -eq $script:QpCounts -or $script:QpCounts.Count -eq 0){
        $qpText.Lines=@(
            'Frames',
            '  |',
            '  |   DRF histogram is generated by the native frame parser.',
            '  |',
            '  +------------------------------------------------ DRF',
            '      Native analysis starts automatically after metadata detection.'
        )
        return
    }
    $keys=@($script:QpCounts.Keys | ForEach-Object {[int]$_} | Sort-Object)
    $max=[double](($script:QpCounts.Values | Measure-Object -Maximum).Maximum)
    $height=5
    $matrix=New-Object 'object[]' $height
    for($row=0;$row-lt$height;$row++){$matrix[$row]=New-Object char[] ($keys.Count*3);for($i=0;$i-lt$matrix[$row].Length;$i++){$matrix[$row][$i]=' '}}
    for($i=0;$i-lt$keys.Count;$i++){$value=[double]$script:QpCounts[$keys[$i]];$bars=if($max-gt0){[Math]::Max(1,[Math]::Round($value/$max*$height))}else{0};for($b=0;$b-lt$bars;$b++){$matrix[$height-1-$b][$i*3]='█'}}
    $lines=New-Object Collections.Generic.List[string];$lines.Add('Frames')
    for($row=0;$row-lt$height;$row++){$lines.Add('  | '+(-join $matrix[$row]))}
    $axisWidth=[Math]::Max(20,$keys.Count*3)
    $lines.Add('  +'+('-'*$axisWidth))
    $labels='DRF '+(($keys|ForEach-Object{'{0,3}'-f$_})-join'')
    $lines.Add($labels)
    $qpText.Lines=$lines.ToArray()
    $qpText.SelectionStart=0
    $qpText.SelectionLength=0
    $qpText.ScrollToCaret()
}
function Render {
    if($null -eq $script:Meta) { $summary.Clear(); return }
    $fmt=$script:Meta.format
    $streams=@($script:Meta.streams)
    $video=@($streams | Where-Object { $_.codec_type -eq 'video' })[0]
    $audios=@($streams | Where-Object { $_.codec_type -eq 'audio' })
    $subs=@($streams | Where-Object { $_.codec_type -eq 'subtitle' })
    $fi=Get-Item -LiteralPath $script:File
    $mux=if($fmt.tags.muxing_application){$fmt.tags.muxing_application}elseif($fmt.tags.ENCODER){$fmt.tags.ENCODER}else{'N/A'}
    $writer=if($fmt.tags.writing_application){$fmt.tags.writing_application}else{'N/A'}
    $nativeContainer=if($script:NativeInfo){$script:NativeInfo.Container}else{'N/A'};$nativeDocType=if($script:NativeInfo -and $script:NativeInfo.DocType){$script:NativeInfo.DocType}else{'N/A'};$nativeTrackCount=if($script:NativeInfo){$script:NativeInfo.Tracks.Count}else{0}
    $lines=@('[ File ]','',"Name:               $($fi.Name)","Modified:           $($fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))","Size:               $('{0:N0}' -f $fi.Length) bytes ($(Bytes $fi.Length))","Duration:           $(Dur $fmt.duration)","Container:          $(NA $fmt.format_long_name)","Native detection:   $nativeContainer","Native DocType:     $nativeDocType","Native tracks:      $nativeTrackCount","Tracks:             $($streams.Count) (video $(@($streams|Where-Object{$_.codec_type -eq 'video'}).Count), audio $($audios.Count), subtitles $($subs.Count))","Muxing library:     $mux","Writing application: $writer")
    if($script:NativeInfo -and $script:NativeInfo.Tracks.Count -gt 0){$lines+=@('','[ Native Matroska Tracks ]','');foreach($nt in $script:NativeInfo.Tracks){$detail=if($nt.Kind -eq 'video'){"$($nt.Width) x $($nt.Height)"}elseif($nt.Kind -eq 'audio'){if($nt.OutputSampleRate -gt 0){"core $($nt.CoreSampleRate) Hz / $($nt.CoreAudioChannels) ch, output $($nt.OutputSampleRate) Hz / $($nt.AudioChannels) ch"}else{"$($nt.SamplingRate) Hz, $($nt.Channels) ch"}}else{''};$lines+=("Track {0}: {1} | {2} | {3} | {4}" -f $nt.Number,$nt.Kind,$nt.CodecId,$nt.Language,$detail)}}
    if($script:NativeInfo){
        $nativeVideo=@($script:NativeInfo.Tracks|Where-Object{$_.Kind -eq 'video'})[0]
        $script:HevcHvccProbe=$null
        if($nativeVideo -and $nativeVideo.CodecId -eq 'V_MPEGH/ISO/HEVC' -and $nativeVideo.CodecPrivate){
            try {
                $script:HevcHvccProbe=[HevcHvccContextProbe]::Parse([byte[]]$nativeVideo.CodecPrivate)
                Write-Host ("REAL hvcC CONTEXT PASS: " + $script:HevcHvccProbe.ToString()) -ForegroundColor Green
            } catch {
                Write-Host ("REAL hvcC CONTEXT FAIL: " + $_.Exception.Message) -ForegroundColor Red
            }
        }
        if($nativeVideo -and $nativeVideo.CodecPrivate){
            if($nativeVideo.CodecId -eq 'V_MPEGH/ISO/HEVC'){
                $lines+=@('','[ Native HEVC Configuration ]','',"NAL length size:     $($nativeVideo.NalLengthSize) bytes","Profile / Tier:     $(NA $nativeVideo.Profile) / $(if($nativeVideo.HevcTier){'High'}else{'Main'})","Level:              $(if($nativeVideo.HevcLevel -gt 0){'{0:N1}' -f ($nativeVideo.HevcLevel/30.0)}else{'N/A'})","Chroma format:      $(NA $nativeVideo.Chroma)","Bit depth:          $($nativeVideo.BitDepth) bit","Temporal layers:    $(if($nativeVideo.HevcTemporalLayers -gt 0){$nativeVideo.HevcTemporalLayers}else{'N/A'})","Dependent slices:   $(if($nativeVideo.HevcDependentSliceSegments){'Enabled'}else{'Disabled'})","Extra header bits:  $($nativeVideo.HevcExtraSliceHeaderBits)","CABAC init flag:     $(if($nativeVideo.HevcCabacInitPresent){'Present'}else{'Not present'})","Default refs L0 / L1: $([int](1+$nativeVideo.HevcNumRefL0)) / $([int](1+$nativeVideo.HevcNumRefL1))","PPS initial QP:      $([int](26+$nativeVideo.HevcPicInitQpMinus26))","CU QP delta:         $(if($nativeVideo.HevcCuQpDeltaEnabled){'Enabled, depth '+$nativeVideo.HevcDiffCuQpDeltaDepth}else{'Disabled'})","Weighted P / B:      $(if($nativeVideo.HevcWeightedPred){'Yes'}else{'No'}) / $(if($nativeVideo.HevcWeightedBipred){'Yes'}else{'No'})","Tiles / WPP:         $(if($nativeVideo.HevcTilesEnabled){'Yes'}else{'No'}) / $(if($nativeVideo.HevcWppEnabled){'Yes'}else{'No'})","Deblocking control:  $(if($nativeVideo.HevcDeblockingControlPresent){'Present'}else{'Not present'})","Ref-list modification:  $(if($nativeVideo.HevcListsModificationPresent){'Present'}else{'Not present'})","Configuration:      hvcC / VPS + SPS + PPS")
            } else {
                $lines+=@('','[ Native AVC Configuration ]','',"NAL length size:     $($nativeVideo.NalLengthSize) bytes","Chroma format:      $(NA $nativeVideo.Chroma)","Reference frames:   $(if($nativeVideo.RefFrames -gt 0){$nativeVideo.RefFrames}else{'N/A'})","Entropy coding:     $(if($nativeVideo.Cabac){'CABAC'}else{'CAVLC / N/A'})","Weighted prediction: $(if($nativeVideo.WeightedPred){'P slices - explicit'}else{'Disabled'})","Weighted bipred:    $(switch($nativeVideo.WeightedBipred){1{'Explicit'}2{'Implicit'}default{'Disabled'}})","8x8 transform:      $(if($nativeVideo.Transform8x8){'Yes'}else{'No / not signaled'})","Deblocking control:  $(if($nativeVideo.DeblockingFilterControlPresent){'Present'}else{'Not present'})","Redundant pic count: $(if($nativeVideo.RedundantPicCntPresent){'Present'}else{'Not present'})","PPS initial QP:      $([int](26+$nativeVideo.PicInitQpMinus26))")
            }
        }
    }

    if($nativeVideo -and $nativeVideo.CodecId -eq 'V_MPEGH/ISO/HEVC'){
        $hp=$script:HevcHvccProbe
        if($hp -and $hp.Sps -and $hp.Pps){
            $lines+=@('','[ Native HEVC hvcC Context Probe ]','',
                "SPS ID:                         $($hp.Sps.SpsId)",
                "PPS ID / referenced SPS ID:     $($hp.Pps.PpsId) / $($hp.Pps.SpsId)",
                "SPS/PPS link:                   $(if($hp.Linked){'PASS'}else{'FAIL'})",
                "Native SPS size:                $($hp.Sps.Width) x $($hp.Sps.Height)",
                "Native SPS chroma:              $($hp.Sps.ChromaFormatIdc)",
                "Native SPS bit depth L/C:       $($hp.Sps.BitDepthLuma) / $($hp.Sps.BitDepthChroma)",
                "Native SPS POC LSB bits:        $($hp.Sps.Log2MaxPicOrderCntLsb)",
                "Native SPS CTB size/grid:        $([int](1 -shl $hp.Sps.Log2CtbSize)) / $($hp.Sps.CtbWidth) x $($hp.Sps.CtbHeight)",
                "Native SPS short-term RPS:       $($hp.Sps.NumShortTermRefPicSets)",
                "Native SPS RPS delta pictures:   $([string]::Join(',', [int[]]$hp.Sps.NumDeltaPocs))",
                "Native SPS long-term refs:       $($hp.Sps.NumLongTermRefPicsSps)",
                "Native SPS SAO / temporal MVP:   $($hp.Sps.SampleAdaptiveOffsetEnabled) / $($hp.Sps.TemporalMvpEnabled)",
                "Native PPS initial QP:          $($hp.Pps.InitialQp)",
                "Native PPS refs L0 / L1:        $([int](1+$hp.Pps.DefaultL0Minus1)) / $([int](1+$hp.Pps.DefaultL1Minus1))",
                "Native PPS weighted P / B:      $($hp.Pps.WeightedPred) / $($hp.Pps.WeightedBipred)",
                "Native PPS tiles / WPP:         $($hp.Pps.TilesEnabled) / $($hp.Pps.WppEnabled)",
                "Native PPS list modification:   $($hp.Pps.ListsModificationPresent)",
                'hvcC context validation:         PASS')
        } else {
            $lines+=@('','[ Native HEVC hvcC Context Probe ]','','hvcC context validation:         FAIL or unavailable')
        }
    }
    if($video){
        $level=if($video.level){'{0:N1}' -f ([double]$video.level/10)}else{'N/A'}
        $depth=if($video.bits_per_raw_sample){$video.bits_per_raw_sample}elseif(([string]$video.pix_fmt)-match'(9|10|12|14|16)'){$matches[1]}else{8}
        $color="$(NA $video.color_primaries) / $(NA $video.color_transfer) / $(NA $video.color_space) / $(NA $video.color_range)"
        $lines+=@('','[ Video ]','',"Codec:              $(NA $video.codec_long_name)",$(if($video.profile -and $level -ne 'N/A'){"Profile / Level:    $($video.profile)@L$level"}else{"Profile / Level:    N/A"}),"Resolution:         $($video.width) x $($video.height)","Aspect ratio:       $(Ratio $video.width $video.height)",$(if((FPS $video) -ne 'N/A'){"Frame rate:         $(FPS $video) fps"}elseif($script:FrameResult -and $script:Duration -gt 0){"Frame rate:         $('{0:N3}' -f ($script:FrameResult.Count/$script:Duration)) fps (derived)"}else{"Frame rate:         N/A"}),"Pixel format:       $(NA $video.pix_fmt)","Bit depth:          $depth bit","Color:              $color")
        if($script:PacketResult){
            $r=$script:PacketResult
            $fv=0;if($script:FrameResult -and $script:Duration -gt 0){$fv=$script:FrameResult.Count/$script:Duration};$rr=$video.avg_frame_rate -split '/';if($fv -le 0 -and $rr.Count -eq 2 -and [double]$rr[1] -ne 0){$fv=[double]$rr[0]/[double]$rr[1]}
            $qf=if($fv -and $video.width -and $video.height){$r.Bitrate/([double]$video.width*$video.height*$fv)}else{0}
            $nativeVideoTrack=@($script:NativeInfo.Tracks|Where-Object{$_.Kind -eq 'video'})[0]
            $codecPrivateBytes=if($nativeVideoTrack -and $nativeVideoTrack.CodecPrivate){$nativeVideoTrack.CodecPrivate.Length}else{0}
            $encodedVideoTotal=$r.Total+$codecPrivateBytes
            $lines+=@("Packet engine:       $script:PacketEngine","Packets:            $('{0:N0}' -f $r.Count)","Key packets:        $('{0:N0}' -f $r.Key)","Packet payload:     $('{0:N0}' -f $r.Total) bytes ($(Bytes $r.Total))","Codec configuration: $('{0:N0}' -f $codecPrivateBytes) bytes","Encoded video total: $('{0:N0}' -f $encodedVideoTotal) bytes ($(Bytes $encodedVideoTotal))","Bitrate:            $(Rate $r.Bitrate)",$(if($fv -gt 0){"Qf:                 $('{0:N6}' -f $qf)"}else{"Qf:                 N/A"}),"Packet size:        avg $(Bytes ([long]$r.Average)), min $(Bytes $r.Minimum), max $(Bytes $r.Maximum)","Key interval:       avg $('{0:N2}' -f $r.GopAverage), min $('{0:N0}' -f $r.GopMinimum), max $('{0:N0}' -f $r.GopMaximum)")
        }
    }
    foreach($audio in $audios){$lang=if($audio.tags.language){$audio.tags.language}else{'und'};$codec="$(NA $audio.codec_long_name)";if($audio.profile){$codec+=' '+$audio.profile};$nativeAudio=@($script:NativeInfo.Tracks|Where-Object{$_.Kind -eq 'audio'})[$audio.index-1];$lines+=@('',("[ Audio #{0} ]" -f $audio.index),'',"Codec:              $codec",$(if($nativeAudio -and $nativeAudio.CoreSampleRate -gt 0){"Core sample rate:   $($nativeAudio.CoreSampleRate) Hz"}else{"Core sample rate:   N/A"}),"Output sample rate: $(NA $audio.sample_rate) Hz",$(if($nativeAudio -and $nativeAudio.CoreAudioChannels -gt 0){"Core channels:      $($nativeAudio.CoreAudioChannels)"}else{"Core channels:      N/A"}),"Output channels:    $(NA $audio.channels)","Output layout:      $(NA $audio.channel_layout)",$(if($nativeAudio){"SBR / PS:           $(if($nativeAudio.Sbr){'Yes'}else{'No'}) / $(if($nativeAudio.Ps){'Yes'}else{'No'})"}else{"SBR / PS:           N/A"}),"Bitrate:            $(Rate $audio.bit_rate)","Language:           $lang")}
    if($subs.Count){$lines+=@('','[ Subtitles ]','');foreach($sub in $subs){$lang=if($sub.tags.language){$sub.tags.language}else{'und'};$lines+=("#{0}: {1} [{2}]" -f $sub.index,(NA $sub.codec_long_name),$lang)}}
    if($script:FrameResult){$r=$script:FrameResult;$match=if($script:PacketResult -and $script:PacketResult.Count -eq $r.Count){'Yes'}else{'No'};if($nativeVideo.CodecId -eq 'V_MPEGH/ISO/HEVC'){$hd=$script:HevcDiagnostic;$lines+=@('','[ Native HEVC Stream Analysis ]','',"Total pictures:     $('{0:N0}' -f $r.Count)","VCL NAL units:      $('{0:N0}' -f $hd.Vcl)","IRAP pictures:      $('{0:N0}' -f $hd.Irap)","IDR / CRA / BLA:    $('{0:N0}' -f $hd.Idr) / $('{0:N0}' -f $hd.Cra) / $('{0:N0}' -f $hd.Bla)","TRAIL / RADL / RASL: $('{0:N0}' -f $hd.Trail) / $('{0:N0}' -f $hd.Radl) / $('{0:N0}' -f $hd.Rasl)","Key frames:         $('{0:N0}' -f $r.Key)","GOP length:         avg $('{0:N2}' -f $r.GopAverage), min $('{0:N0}' -f $r.GopMinimum), max $('{0:N0}' -f $r.GopMaximum)","Packet/frame match: $match","I-pictures:         $('{0:N0}' -f $r.I) ($(Pct $r.I $r.Count))","P-pictures:         $('{0:N0}' -f $r.P) ($(Pct $r.P $r.Count))","B-pictures:         $('{0:N0}' -f $r.B) ($(Pct $r.B $r.Count))","Other pictures:     $('{0:N0}' -f $r.Other) ($(Pct $r.Other $r.Count))","Slice headers:      $('{0:N0}' -f $hd.SliceParsed) parsed / $('{0:N0}' -f $hd.SliceRejected) rejected","Native all-suffix checkpoint: $('{0:N0}' -f $hd.PrefixParsed) parsed / $('{0:N0}' -f $hd.PrefixRejected) rejected",
"All-suffix failure: $(if($hd.PrefixFirstError){$hd.PrefixFirstError}else{'None'})",
$(if($hd.SliceParsed -eq $r.Count -and $hd.SliceRejected -eq 0 -and ($r.I+$r.P+$r.B) -eq $r.Count){'HEVC I/P/B validation: Yes'}else{'HEVC I/P/B validation: Incomplete'}))}else{$lines+=@('','[ Native Stream Analysis ]','',"Total frames:       $('{0:N0}' -f $r.Count)","I-frames:           $('{0:N0}' -f $r.I) ($(Pct $r.I $r.Count))","P-frames:           $('{0:N0}' -f $r.P) ($(Pct $r.P $r.Count))","B-frames:           $('{0:N0}' -f $r.B) ($(Pct $r.B $r.Count))","Other frames:       $('{0:N0}' -f $r.Other) ($(Pct $r.Other $r.Count))","Key frames:         $('{0:N0}' -f $r.Key)","GOP length:         avg $('{0:N2}' -f $r.GopAverage), min $('{0:N0}' -f $r.GopMinimum), max $('{0:N0}' -f $r.GopMaximum)","Packet/frame match: $match")}}
    if($nativeVideo.CodecId -eq 'V_MPEGH/ISO/HEVC'){
        $lines+=@('','[ HEVC QP Analysis ]','',"PPS initial QP:      $([int](26+$nativeVideo.HevcPicInitQpMinus26))","CU QP delta:         $(if($nativeVideo.HevcCuQpDeltaEnabled){'Enabled'}else{'Disabled'})","Weighted prediction: $(if($nativeVideo.HevcWeightedPred -or $nativeVideo.HevcWeightedBipred){'Present'}else{'Disabled'})","Tiles / WPP:         $(if($nativeVideo.HevcTilesEnabled){'Yes'}else{'No'}) / $(if($nativeVideo.HevcWppEnabled){'Yes'}else{'No'})",'SliceQPY output:     Generated by native HEVC slice parser','Safety mode:         Only deterministically parsed HEVC QP values are emitted')
    }
    $qpCodecLabel=if($nativeVideo.CodecId -eq 'V_MPEGH/ISO/HEVC'){'HEVC'}elseif($nativeVideo.CodecId -eq 'V_MPEG4/ISO/AVC'){'AVC'}else{'Video'}
    if($script:SliceQpDiagnostic -and $script:SliceQpDiagnostic.Parsed -gt 0){
        $sd=$script:SliceQpDiagnostic
        $lines+=@('',"[ $qpCodecLabel QP Validation ]",'',"Headers parsed:     $('{0:N0}' -f $sd.Parsed)","Headers rejected:   $('{0:N0}' -f $sd.Failed)","I parsed/rejected:  $('{0:N0}' -f $sd.IOk) / $('{0:N0}' -f $sd.IFail)","P parsed/rejected:  $('{0:N0}' -f $sd.POk) / $('{0:N0}' -f $sd.PFail)","B parsed/rejected:  $('{0:N0}' -f $sd.BOk) / $('{0:N0}' -f $sd.BFail)","Failures EOF/align/QP: $('{0:N0}' -f $sd.Eof) / $('{0:N0}' -f $sd.Alignment) / $('{0:N0}' -f $sd.Qp)","Failures list/mark/other: $('{0:N0}' -f $sd.RefList) / $('{0:N0}' -f $sd.Marking) / $('{0:N0}' -f $sd.Other)","First failure:      $(if($sd.FirstError){$sd.FirstError}else{'None'})","SliceQPY average:   $('{0:N6}' -f $sd.Average)","SliceQPY range:     $($sd.Minimum) .. $($sd.Maximum)",$(if($sd.Failed -eq 0){'Validated: one SliceQPY value was obtained for every video frame.'}else{'Diagnostic incomplete: rejected headers prevent final DRF output.'}))
    }
    if($script:SliceQpDiagnostic -and $script:QpCounts.Count){
        $sd=$script:SliceQpDiagnostic
        $qpComplete=($sd.Failed -eq 0 -and $script:FrameResult -and $sd.Parsed -eq $script:FrameResult.Count)
        $qpValidationNote=if($qpComplete){"Native $qpCodecLabel slice parser completed all frames; no external tool required."}else{"Native $qpCodecLabel QP analysis incomplete."}
        $lines+=@('',"[ $qpCodecLabel DRF / QP Analysis ]",'',"Values / frames:    $('{0:N0}' -f $sd.Parsed) / $('{0:N0}' -f $script:FrameResult.Count)","Average DRF:        $('{0:N6}' -f $sd.Average)","Standard deviation: $('{0:N6}' -f $sd.StdDev)","Minimum / maximum:  $($sd.Minimum) / $($sd.Maximum)","I-slice QP average:   $('{0:N6}' -f $sd.IAverage)","P-slice QP average:   $('{0:N6}' -f $sd.PAverage)","B-slice QP average:   $('{0:N6}' -f $sd.BAverage)","I/P/B std. deviation:    $('{0:N6}' -f $sd.IStdDev) / $('{0:N6}' -f $sd.PStdDev) / $('{0:N6}' -f $sd.BStdDev)","Native QP count:      $($sd.Parsed) / $($script:FrameResult.Count)","Native QP completeness: $(if($qpComplete){'PASS'}else{'INCOMPLETE'})","Histogram source:     Native $qpCodecLabel slice headers","External dependency:  None","Validation note:      $qpValidationNote")
    }
    $isHevc=($nativeVideo.CodecId -eq 'V_MPEGH/ISO/HEVC');$drfStatus=if($script:QpCounts.Count){'Frame-level SliceQPY histogram generated successfully.'}elseif($isHevc){'HEVC SliceQPY was not generated.'}else{'Unavailable: complete native frame-level QP values were not obtained.'};$lines+=@('','[ Native Engine ]','','Container demux:     Matroska / WebM',"Video configuration: $(if($isHevc){'HEVC hvcC / VPS / SPS / PPS record'}else{'AVC SPS / PPS / VUI'})",'Audio configuration: AAC AudioSpecificConfig',"Frame structure:     $(if($isHevc){'HEVC NAL + first-slice I / P / B analysis'}else{'Native H.264 I / P / B slices'})","DRF / QP source:     Native frame-level SliceQPY",'Processing model:    Single pass / in-memory safe','External tools:      None','','[ DRF / QP ]','',$drfStatus)
    $labelWidth=29
    $aligned=New-Object Collections.Generic.List[string]
    foreach($line in $lines){
        if($line -notmatch '^Track\s+\d+:' -and $line -match '^([^:]{2,32}:)\s*(.*)$'){
            $aligned.Add(("{0,-29} {1}" -f $Matches[1],$Matches[2]))
        }else{$aligned.Add([string]$line)}
    }
    $summary.Lines=$aligned.ToArray()
    $summary.SelectionStart=0
    $summary.SelectionLength=0
    $summary.ScrollToCaret()
    Render-QpHistogram
}
function Busy([bool]$v){$open.Enabled = -not $v;$cancel.Enabled = $v;$copy.Enabled=(-not $v -and $summary.TextLength -gt 0);$drop.Enabled = -not $v;$bar.Visible = $v;if(-not $v){$status.Text='Quick metadata loaded - starting Deep analysis'}}
function Log($s){$log.AppendText($s+[Environment]::NewLine);$log.SelectionStart=$log.TextLength;$log.ScrollToCaret()}

# Dark application style
$RoyalBg=[Drawing.Color]::FromArgb(10,12,18)
$RoyalPanel=[Drawing.Color]::FromArgb(20,24,34)
$RoyalPanel2=[Drawing.Color]::FromArgb(27,32,45)
$RoyalBlue=[Drawing.Color]::FromArgb(42,92,190)
$RoyalBlueHi=[Drawing.Color]::FromArgb(74,132,242)
$RoyalGold=[Drawing.Color]::FromArgb(214,174,74)
$RoyalText=[Drawing.Color]::FromArgb(232,237,247)
$RoyalMuted=[Drawing.Color]::FromArgb(153,165,188)
$RoyalBorder=[Drawing.Color]::FromArgb(55,65,88)
function Style-Button($button,[bool]$primary=$false){
    $button.FlatStyle='Flat';$button.FlatAppearance.BorderSize=1
    $button.FlatAppearance.BorderColor=if($primary){$RoyalBlueHi}else{$RoyalBorder}
    $button.BackColor=if($primary){$RoyalBlue}else{$RoyalPanel2};$button.ForeColor=$RoyalText
    $button.FlatAppearance.MouseOverBackColor=if($primary){$RoyalBlueHi}else{[Drawing.Color]::FromArgb(40,47,64)}
    $button.FlatAppearance.MouseDownBackColor=[Drawing.Color]::FromArgb(25,61,132)
}
function Apply-DarkTheme {
    $form.BackColor=$RoyalBg;$form.ForeColor=$RoyalText
    $title.ForeColor=$RoyalGold;$fileText.ForeColor=$RoyalText;$status.ForeColor=$RoyalGold
    Style-Button $open $true;Style-Button $cancel;Style-Button $copy
    $drop.BackColor=$RoyalPanel;$drop.ForeColor=$RoyalGold;$dl.ForeColor=$RoyalGold
    foreach($box in @($chartBox,$qpBox)){$box.ForeColor=$RoyalGold;$box.BackColor=$RoyalBg}
    $chart.BackColor=$RoyalPanel;$qpText.BackColor=$RoyalPanel;$qpText.ForeColor=$RoyalText;$qpText.BorderStyle='FixedSingle'
    $tabs.BackColor=$RoyalBg;$tabs.ForeColor=$RoyalText
    foreach($page in $tabs.TabPages){$page.BackColor=$RoyalPanel;$page.ForeColor=$RoyalText}
    foreach($text in @($summary,$json,$log)){$text.BackColor=$RoyalPanel;$text.ForeColor=$RoyalText;$text.BorderStyle='FixedSingle'}
    $grid.BackgroundColor=$RoyalPanel;$grid.GridColor=$RoyalBorder;$grid.BorderStyle='FixedSingle';$grid.EnableHeadersVisualStyles=$false
    $grid.ColumnHeadersDefaultCellStyle.BackColor=$RoyalPanel2;$grid.ColumnHeadersDefaultCellStyle.ForeColor=$RoyalGold
    $grid.DefaultCellStyle.BackColor=$RoyalPanel;$grid.DefaultCellStyle.ForeColor=$RoyalText;$grid.DefaultCellStyle.SelectionBackColor=$RoyalBlue;$grid.DefaultCellStyle.SelectionForeColor=$RoyalText
}

$form=New-Object Windows.Forms.Form;$form.Text="Little Stream Detector (LSD) 1.0";$form.ClientSize=New-Object Drawing.Size(960,810);$form.MinimumSize=New-Object Drawing.Size(760,680);$form.StartPosition='CenterScreen';$form.AllowDrop=$true;$form.KeyPreview=$true;$form.Font=New-Object Drawing.Font('Segoe UI',9)
function Label($t,$x,$y,$w,$h){$c=New-Object Windows.Forms.Label;$c.Text=$t;$c.SetBounds($x,$y,$w,$h);$c}
$title=Label 'Little Stream Detector (LSD)' 20 12 520 38;$title.Font=New-Object Drawing.Font('Segoe UI',20,[Drawing.FontStyle]::Bold);$sub=Label '' 0 0 0 0;$sub.Visible=$false
$open=New-Object Windows.Forms.Button;$open.Text='Open video';$open.SetBounds(20,58,122,32);$cancel=New-Object Windows.Forms.Button;$cancel.Text='Cancel';$cancel.SetBounds(150,58,80,32);$cancel.Enabled=$false;$copy=New-Object Windows.Forms.Button;$copy.Text='Copy';$copy.SetBounds(238,58,88,32);$copy.Enabled=$false;$fileText=Label 'Drop a video or click Open video.' 338 65 596 24;$fileText.AutoEllipsis=$true;$fileText.Anchor='Top,Left,Right'
$drop=New-Object Windows.Forms.Panel;$drop.SetBounds(20,100,914,72);$drop.Anchor='Top,Left,Right';$drop.BorderStyle='FixedSingle';$drop.AllowDrop=$true;$dl=Label 'DROP VIDEO HERE' 0 0 914 72;$dl.Dock='Fill';$dl.TextAlign='MiddleCenter';$dl.Font=New-Object Drawing.Font('Segoe UI',12,[Drawing.FontStyle]::Bold);$drop.Controls.Add($dl)
$bar=New-Object Windows.Forms.ProgressBar;$bar.SetBounds(20,181,914,8);$bar.Style='Continuous';$bar.Visible=$false
$chartBox=New-Object Windows.Forms.GroupBox;$chartBox.Text='Bitrate profile';$chartBox.SetBounds(20,198,914,142);$chartBox.Anchor='Top,Left,Right';$chart=New-Object Windows.Forms.Panel;$chart.Dock='Fill';$chart.BackColor=$RoyalPanel;$chartBox.Controls.Add($chart);$qpBox=New-Object Windows.Forms.GroupBox;$qpBox.Text='DRF distribution (frame-level SliceQPY)';$qpBox.SetBounds(20,348,914,154);$qpBox.Anchor='Top,Left,Right';$qpText=New-Object Windows.Forms.TextBox;$qpText.Multiline=$true;$qpText.ReadOnly=$true;$qpText.WordWrap=$false;$qpText.ScrollBars='Horizontal';$qpText.Dock='Fill';$qpText.Font=New-Object Drawing.Font('Consolas',9);$qpText.BackColor=$RoyalPanel;$qpText.ForeColor=$RoyalText;$qpBox.Controls.Add($qpText);$tabs=New-Object Windows.Forms.TabControl;$tabs.SetBounds(20,510,914,260);$tabs.Anchor='Top,Bottom,Left,Right'
$summary=New-Object Windows.Forms.TextBox;$summary.Multiline=$true;$summary.ReadOnly=$true;$summary.ScrollBars='Both';$summary.WordWrap=$false;$summary.Dock='Fill';$summary.Font=New-Object Drawing.Font('Consolas',9)
$grid=New-Object Windows.Forms.DataGridView;$grid.Dock='Fill';$grid.ReadOnly=$true;$grid.AllowUserToAddRows=$false;$grid.RowHeadersVisible=$false;$grid.AutoSizeColumnsMode='Fill'
$json=New-Object Windows.Forms.TextBox;$json.Multiline=$true;$json.ReadOnly=$true;$json.ScrollBars='Both';$json.WordWrap=$false;$json.Dock='Fill';$json.Font=New-Object Drawing.Font('Consolas',9)
$log=New-Object Windows.Forms.TextBox;$log.Multiline=$true;$log.ReadOnly=$true;$log.ScrollBars='Both';$log.WordWrap=$false;$log.Dock='Fill';$log.Font=New-Object Drawing.Font('Consolas',9)
foreach($z in @(@('Summary',$summary),@('Streams',$grid),@('JSON',$json),@('Log',$log))){$pg=New-Object Windows.Forms.TabPage;$pg.Text=$z[0];$pg.Controls.Add($z[1]);$tabs.TabPages.Add($pg)|Out-Null}
$status=Label 'Ready' 20 778 914 22;$status.Anchor='Bottom,Left,Right';$form.Controls.AddRange(@($title,$sub,$open,$cancel,$copy,$fileText,$drop,$bar,$chartBox,$qpBox,$tabs,$status));Apply-DarkTheme;Render-QpHistogram
function Build-NativeMetadata {
    if($null -eq $script:NativeInfo){throw 'Native media information is not available.'}
    $streams=New-Object Collections.Generic.List[object]
    $index=0
    foreach($t in $script:NativeInfo.Tracks){
        $codecName=switch($t.CodecId){'V_MPEG4/ISO/AVC'{'h264'};'V_MPEGH/ISO/HEVC'{'hevc'};'A_AAC'{'aac'};default{$t.CodecId}}
        $codecLong=switch($t.CodecId){'V_MPEG4/ISO/AVC'{'H.264 / AVC'};'V_MPEGH/ISO/HEVC'{'H.265 / HEVC'};'A_AAC'{'AAC'};default{$t.CodecId}}
        $streams.Add([pscustomobject]@{
            index=$index;codec_type=$t.Kind;codec_name=$codecName;codec_long_name=$codecLong;profile=if($t.Kind -eq 'video'){$t.Profile}elseif($t.Kind -eq 'audio'){$t.AudioProfile}else{$null};level=if($t.Level -gt 0){[int]([Math]::Round($t.Level*10))}else{$null}
            width=$t.Width;height=$t.Height;avg_frame_rate=if($t.FrameRate -gt 0){('{0}/1000' -f [int]([Math]::Round($t.FrameRate*1000)))}else{'0/0'};sample_aspect_ratio=if($t.PixelAspect){$t.PixelAspect}else{$null};display_aspect_ratio=$null
            pix_fmt=if($t.Chroma -eq 'YUV 4:2:0'){'yuv420p'}else{$null};bits_per_raw_sample=if($t.BitDepth -gt 0){$t.BitDepth}else{$null};color_primaries=if($t.ColorPrimaries){$t.ColorPrimaries}else{$null};color_transfer=if($t.ColorTransfer){$t.ColorTransfer}else{$null};color_space=if($t.ColorMatrix){$t.ColorMatrix}else{$null};color_range=if($t.ColorRange){$t.ColorRange}else{$null}
            sample_rate=if($t.OutputSampleRate -gt 0){$t.OutputSampleRate}elseif($t.SamplingRate -gt 0){[int]$t.SamplingRate}else{$null};channels=if($t.AudioChannels -gt 0){$t.AudioChannels}elseif($t.Channels -gt 0){$t.Channels}else{$null};channel_layout=if($t.AudioChannels -eq 2){'stereo'}elseif($t.AudioChannels -eq 1){'mono'}else{$null};bit_rate=$null
            tags=[pscustomobject]@{language=if($t.Language){$t.Language}else{'und'}}
        });$index++
    }
    [pscustomobject]@{
        streams=$streams.ToArray()
        format=[pscustomobject]@{
            duration=$script:NativeInfo.DurationSeconds;format_name=$script:NativeInfo.DocType;format_long_name=$script:NativeInfo.Container
            tags=[pscustomobject]@{muxing_application=$script:NativeInfo.MuxingApp;writing_application=$script:NativeInfo.WritingApp}
        }
    }
}
function Build-Base($d) {
    $script:Meta=$d
    $script:Duration=if($d.format.duration){[double]$d.format.duration}else{0}
    $json.Text=$d | ConvertTo-Json -Depth 20
    $dt=New-Object Data.DataTable
    foreach($c in @('#','Type','Codec','Profile','Parameters','Rate','Bitrate','Language')){[void]$dt.Columns.Add($c)}
    foreach($x in @($d.streams)){$row=$dt.NewRow();$row.'#'=$x.index;$row.Type=$x.codec_type;$row.Codec=$x.codec_name;$row.Profile=$x.profile;$row.Parameters=if($x.codec_type -eq 'video'){"$($x.width) x $($x.height)"}elseif($x.codec_type -eq 'audio'){"$($x.channels) ch"}else{''};$row.Rate=if($x.codec_type -eq 'video'){FPS $x}else{$x.sample_rate};$row.Bitrate=Rate $x.bit_rate;$row.Language=if($x.tags.language){$x.tags.language}else{'und'};$dt.Rows.Add($row)}
    $grid.DataSource=$dt
    Render
    $script:Auto=$false
}
function Test-NativeRuntime {
    $issues = New-Object Collections.Generic.List[string]

    if(-not ('NativeMediaProbe' -as [type])) {
        $issues.Add('NativeMediaProbe type is unavailable.')
    }
    if(-not ('NativeMatroskaPacketScan' -as [type])) {
        $issues.Add('NativeMatroskaPacketScan type is unavailable.')
    }
    if(-not ('H264CabacArithmeticDecoder' -as [type])) {
        $issues.Add('H264CabacArithmeticDecoder type is unavailable.')
    }
    try { $null=[H264CabacSelfTest]::Run() } catch { $issues.Add('CABAC self-test failed: '+$_.Exception.Message) }
    if($script:HostedInMemory -ne $true) {
        $issues.Add('In-memory host contract is not active.')
    }

    if($issues.Count -gt 0) {
        throw ($issues -join [Environment]::NewLine)
    }
}

function Start-Meta($path) {
    if($script:ScanJob){return}
    Test-NativeRuntime
    $script:File=$path
    $script:Meta=$null
    $script:PacketResult=$null
    $script:FrameResult=$null
    $script:BitrateBins=@()
    $script:QpCounts=@{}
    $script:SliceQpDiagnostic=$null
    $script:HevcDiagnostic=$null
    $script:Cancelled=$false
    $script:AutoDeep=$false
    $fileText.Text=$path
    $summary.Clear();$json.Clear();$log.Clear();$grid.DataSource=$null
    if($null -ne $chart){$chart.Invalidate()}
    if($null -ne $qpText){Render-QpHistogram}
    Busy $true
    $status.Text='Reading native metadata...'
    try {
        $script:NativeInfo=[NativeMediaProbe]::Inspect($path,$false)
        if($script:NativeInfo.Container -ne 'Matroska / WebM'){
            throw 'The native-only build currently supports Matroska / WebM files.'
        }
        Build-Base (Build-NativeMetadata)
        $status.Text='Quick metadata ready - native stream analysis continues...'
        Log 'Native pipeline: EBML + Matroska + AVC/AAC configuration + H.264 slice types.'
        Log 'Runtime: in-memory EXE host compatible; no external process or temporary file path.'
        Log 'CABAC runtime self-test passed.';Log ('QP/DRF status: '+$script:QpDecoderState.Status+'. No estimated values will be shown.')
        Start-Scan $false
    }
    catch {
        Busy $false
        Log ('Native load failed: '+$_.Exception.Message)
        [Windows.Forms.MessageBox]::Show($_.Exception.Message,'LSD native engine')|Out-Null
    }
}
function Start-Scan([bool]$frames) {
    if(-not $script:Meta -or $script:ScanJob){return}
    $script:ExactMode=$false
    $script:Cancelled=$false
    try {
        $nativeVideo=@($script:NativeInfo.Tracks | Where-Object { $_.Kind -eq 'video' })[0]
        if($null -eq $nativeVideo){throw 'Native Matroska video track was not found.'}
        $script:ScanJob=New-Object NativeMatroskaPacketScan -ArgumentList ([double]$script:Duration),$nativeVideo
        $script:PacketEngine='Native C# Matroska'
        $script:StageStarted=[DateTime]::UtcNow
        $script:ScanJob.Start($script:File,[long]$nativeVideo.Number)
        Busy $true
        $bar.Value=0
        $status.Text='Fast native stream analysis running...'
    }
    catch {
        if($script:ScanJob){$script:ScanJob.Dispose()}
        $script:ScanJob=$null
        Busy $false
        Log ('Native analysis failed: '+$_.Exception.Message)
        [Windows.Forms.MessageBox]::Show($_.Exception.Message,'LSD native analysis error')|Out-Null
    }
}

function Finish-Scan([bool]$frames,[string]$value,$bins) {
    $x=$value -split '\|'
    $result=[pscustomobject]@{Count=[long]$x[0];Key=[long]$x[1];Total=[long]$x[2];Minimum=[long]$x[3];Maximum=[long]$x[4];GopMinimum=[long]$x[5];GopMaximum=[long]$x[6];I=[long]$x[7];P=[long]$x[8];B=[long]$x[9];Other=[long]$x[10];Bitrate=[double]::Parse($x[11],[Globalization.CultureInfo]::InvariantCulture);Average=[double]::Parse($x[12],[Globalization.CultureInfo]::InvariantCulture);GopAverage=[double]::Parse($x[13],[Globalization.CultureInfo]::InvariantCulture)}
    if($frames){
        $script:FrameResult=$result
        $script:PacketResult=$result
        $script:PacketEngine='Deep single-pass frame stream'
        $script:BitrateBins=@($bins)
        if($null -ne $chart){$chart.Invalidate()}
    }
    else {
        $script:PacketResult=$result
        if(($result.I+$result.P+$result.B+$result.Other) -gt 0){$script:FrameResult=$result}
        $script:BitrateBins=@($bins)
        if($null -ne $chart){$chart.Invalidate()}
    }
    $hv=@($script:NativeInfo.Tracks|Where-Object{$_.Type -eq 1}|Select-Object -First 1)
    if($hv -and $hv.CodecId -eq 'V_MPEGH/ISO/HEVC' -and $script:NativeHevcQpDiagnostic){
        $script:SliceQpDiagnostic=$script:NativeHevcQpDiagnostic
        $script:NativeHevcQpValidated=($script:SliceQpDiagnostic.Failed -eq 0 -and $script:FrameResult -and $script:SliceQpDiagnostic.Parsed -eq $script:FrameResult.Count)
        $script:NativeHevcQpReason=if($script:NativeHevcQpValidated){'Native HEVC slice parser completed all frames; no external tool required.'}else{'Native HEVC QP validation incomplete.'}
    }
    if($script:SliceQpDiagnostic -and $script:FrameResult -and $script:SliceQpDiagnostic.Failed -eq 0 -and $script:SliceQpDiagnostic.Parsed -eq $script:FrameResult.Count) {
        $script:QpCounts=@{}
        foreach($pair in ($script:SliceQpDiagnostic.Histogram -split ',')) {
            if($pair){$kv=$pair -split ':';if($kv.Count -eq 2){$script:QpCounts[[int]$kv[0]]=[long]$kv[1]}}
        }
    }
    Render
}
function Cancel{$script:Cancelled=$true;if($script:ScanJob){$script:ScanJob.Cancel()}}

$toolTip=New-Object Windows.Forms.ToolTip;$toolTip.SetToolTip($open,'Native-only Matroska analysis. No external multimedia engine is used.')
$chart.Add_Paint({
    param($sender,$e)
    $g=$e.Graphics;$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::None
    $r=$sender.ClientRectangle;$g.Clear($RoyalPanel)
    if($script:BitrateBins.Count -lt 2){$f=New-Object Drawing.Font('Segoe UI',9);$g.DrawString('Native stream analysis continues automatically after quick metadata.',$f,(New-Object Drawing.SolidBrush($RoyalMuted)),10,10);$f.Dispose();return}
    $max=($script:BitrateBins|Measure-Object -Maximum).Maximum;if($max -le 0){return}
    $penGrid=New-Object Drawing.Pen($RoyalBorder,1);for($i=1;$i-lt4;$i++){$y=[int]($r.Height*$i/4);$g.DrawLine($penGrid,0,$y,$r.Width,$y)};$penGrid.Dispose()
    $pen=New-Object Drawing.Pen($RoyalBlueHi,1)
    $n=$script:BitrateBins.Count
    for($i=0;$i-lt$n;$i++){$x=[int]($i*($r.Width-1)/($n-1));$h=[int](($script:BitrateBins[$i]/[double]$max)*($r.Height-24));$g.DrawLine($pen,$x,$r.Height-18,$x,$r.Height-18-$h)}
    $pen.Dispose();$font=New-Object Drawing.Font('Segoe UI',8);$g.DrawString('0:00',$font,(New-Object Drawing.SolidBrush($RoyalMuted)),2,$r.Height-16);$end=Dur $script:Duration;$sz=$g.MeasureString($end,$font);$g.DrawString($end,$font,(New-Object Drawing.SolidBrush($RoyalMuted)),$r.Width-$sz.Width-3,$r.Height-16);$g.DrawString(('Peak bucket: '+(Bytes $max)),$font,(New-Object Drawing.SolidBrush($RoyalMuted)),5,3);$font.Dispose()
})
$timer=New-Object Windows.Forms.Timer
$timer.Interval=100
$timer.Add_Tick({
    try {
        if($script:ScanJob) {
            $bar.Value=[Math]::Min(99,[Math]::Max(0,$script:ScanJob.Progress))
            $status.Text=('{0}% | {1:N0} video packets'-f$bar.Value,$script:ScanJob.Count)
            if($script:ScanJob.Done) {
                $j=$script:ScanJob;$script:ScanJob=$null
                if(-not $script:Cancelled -and $j.ExitCode -eq 0) { $script:HevcDiagnostic=[pscustomobject]@{Vcl=$j.HevcVcl;Irap=$j.HevcIrap;Idr=$j.HevcIdr;Cra=$j.HevcCra;Bla=$j.HevcBla;Trail=$j.HevcTrail;Rasl=$j.HevcRasl;Radl=$j.HevcRadl;SliceParsed=$j.HevcSliceParsed;SliceRejected=$j.HevcSliceRejected;PrefixParsed=$j.HevcPrefixParsed;PrefixRejected=$j.HevcPrefixRejected;PrefixFirstError=$j.HevcPrefixFirstError;NativeTypeSequenceSha256=$j.HevcTypeSequenceHash};$script:SliceQpDiagnostic=[pscustomobject]@{Parsed=$j.SliceHeaderOk;Failed=$j.SliceHeaderFailed;IOk=$j.SliceIOk;POk=$j.SlicePOk;BOk=$j.SliceBOk;IFail=$j.SliceIFail;PFail=$j.SlicePFail;BFail=$j.SliceBFail;Eof=$j.FailEof;Alignment=$j.FailAlignment;Qp=$j.FailQp;RefList=$j.FailRefList;Marking=$j.FailMarking;Other=$j.FailOther;FirstError=$j.FirstSliceError;Average=$j.SliceQpAverage;StdDev=$j.SliceQpStdDev;Minimum=$j.SliceQpMinimum;Maximum=$j.SliceQpMaximum;IAverage=$j.IQpAverage;PAverage=$j.PQpAverage;BAverage=$j.BQpAverage;IStdDev=$j.IQpStdDev;PStdDev=$j.PQpStdDev;BStdDev=$j.BQpStdDev;Histogram=$j.QpHistogram};$script:NativeHevcQpDiagnostic=$script:SliceQpDiagnostic; Finish-Scan $script:ExactMode $j.Result $j.Bins }
                else { Log ('Native analysis failed. '+$j.Error) }
                $j.Dispose();$elapsed=([DateTime]::UtcNow-$script:StageStarted).TotalSeconds;$speed=if($elapsed -gt 0){(Get-Item -LiteralPath $script:File).Length/1MB/$elapsed}else{0};$pps=if($elapsed -gt 0){$script:PacketResult.Count/$elapsed}else{0};Log ('Fast native analysis: {0:N2} s | {1:N1} MiB/s | {2:N0} packets/s.' -f $elapsed,$speed,$pps);Busy $false;$status.Text=('Complete - {0:N1} MiB/s | {1:N0} packets/s' -f $speed,$pps)
            }
        }
    }
    catch {
        Log ('UI timer error: '+$_.Exception.Message)
        $status.Text='Error - see Log tab'
        if($script:ScanJob){$script:ScanJob.Cancel();$script:ScanJob.Dispose();$script:ScanJob=$null}
        Busy $false
        [Windows.Forms.MessageBox]::Show($_.Exception.Message,'LSD runtime error')|Out-Null
    }
})
$timer.Start()
function Pick{$d=New-Object Windows.Forms.OpenFileDialog;$d.Filter='Video files|*.avi;*.mkv;*.mp4;*.m4v;*.mov;*.webm;*.ts;*.m2ts;*.mpg;*.mpeg;*.vob;*.wmv;*.flv;*.ogv;*.264;*.h264;*.265;*.h265;*.hevc|All files|*.*';if($d.ShowDialog() -eq 'OK'){Start-Meta $d.FileName};$d.Dispose()}
$open.Add_Click({Pick});$cancel.Add_Click({Cancel});$copy.Add_Click({if($summary.Text){[Windows.Forms.Clipboard]::SetText($summary.Text);$status.Text='Report copied'}})
$dragEnter={if($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)){$_.Effect='Copy'}else{$_.Effect='None'}};$dragDrop={$f=$_.Data.GetData([Windows.Forms.DataFormats]::FileDrop);if($f.Count){Start-Meta $f[0]}};$form.Add_DragEnter($dragEnter);$form.Add_DragDrop($dragDrop);$drop.Add_DragEnter($dragEnter);$drop.Add_DragDrop($dragDrop);$form.Add_KeyDown({if($_.KeyCode -eq 'Escape'){Cancel}elseif($_.Control-and$_.KeyCode -eq 'O'){Pick}});$form.Add_FormClosing({Cancel;$timer.Stop();if($script:ScanJob){$script:ScanJob.Dispose()};[Threading.Thread]::CurrentThread.CurrentCulture=$script:OriginalCulture;[Threading.Thread]::CurrentThread.CurrentUICulture=$script:OriginalCulture});[void]$form.ShowDialog()