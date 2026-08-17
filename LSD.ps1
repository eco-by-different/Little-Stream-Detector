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
 public bool Av1SequenceValid,Av1StillPicture,Av1ReducedStillPictureHeader,Av1TimingInfoPresent,Av1FrameIdNumbersPresent,Av1Use128x128Superblock,Av1EnableFilterIntra,Av1EnableIntraEdgeFilter,Av1EnableInterintraCompound,Av1EnableMaskedCompound,Av1EnableWarpedMotion,Av1EnableDualFilter,Av1EnableOrderHint,Av1EnableJntComp,Av1EnableRefFrameMvs,Av1EnableSuperres,Av1EnableCdef,Av1EnableRestoration,Av1FilmGrainParamsPresent,Av1ColorDescriptionPresent,Av1ColorRange,Av1SeparateUvDeltaQ; public int Av1MaxFrameWidth,Av1MaxFrameHeight,Av1FrameWidthBits,Av1FrameHeightBits,Av1OperatingPoints,Av1OrderHintBits,Av1ColorPrimaries,Av1TransferCharacteristics,Av1MatrixCoefficients,Av1SequenceBits,Av1ForceScreenContentTools,Av1ForceIntegerMv;
 public bool Av1ConfigValid; public int Av1Marker,Av1Version,Av1Profile,Av1Level,Av1Tier,Av1HighBitdepth,Av1TwelveBit,Av1Monochrome,Av1SubsamplingX,Av1SubsamplingY,Av1ChromaSamplePosition,Av1InitialPresentationDelayMinusOne=-1,Av1ConfigObuBytes,Av1ConfigObuCount,Av1SequenceHeaderObuCount; public string Av1ObuInventory="";
 public bool Cabac,WeightedPred,Transform8x8,Sbr,Ps,HevcConfig,HevcTier,HevcDependentSliceSegments,HevcOutputFlagPresent,HevcCabacInitPresent,HevcCuQpDeltaEnabled,HevcWeightedPred,HevcWeightedBipred,HevcTilesEnabled,HevcWppEnabled,HevcDeblockingControlPresent,HevcDeblockingOverrideEnabled,HevcLoopFilterAcrossSlices,HevcListsModificationPresent; public int HevcProfile,HevcLevel,HevcTemporalLayers,HevcExtraSliceHeaderBits,HevcNumRefL0,HevcNumRefL1,HevcPicInitQpMinus26,HevcDiffCuQpDeltaDepth; public int WeightedBipred; public string ColorPrimaries="",ColorTransfer="",ColorMatrix="",ColorRange=""; public int CoreSampleRate,OutputSampleRate,CoreAudioChannels,AudioChannels; public string AudioProfile="";
 public string Kind { get { return Type==1?"video":Type==2?"audio":Type==17?"subtitle":"other"; } }
}

// LSD 2.0 canonical media model and container-neutral sample index.
public sealed class LsdMediaModel {
 public string SourcePath="",ContainerType="Unknown",ContainerDetail="",AdapterName="MatroskaToLsdAdapter/2.0";
 public long FileLength,TimecodeScale=1000000; public double DurationSeconds;
 public readonly System.Collections.Generic.List<LsdTrackModel> Tracks=new System.Collections.Generic.List<LsdTrackModel>();
 public bool IsValid{get{return ContainerType!="Unknown"&&Tracks.Count>0;}}
 public int CountType(string kind){int n=0;foreach(var t in Tracks)if(t.TrackType==kind)n++;return n;}
}
public sealed class LsdTrackModel {
 public long TrackId; public string TrackType="other",CodecId="",CodecFamily="Unknown",Language="und",PayloadFormat="Unknown";
 public byte[] CodecPrivate; public int NalLengthSize; public long Width,Height,Channels;
 public readonly System.Collections.Generic.List<LsdSampleModel> Samples=new System.Collections.Generic.List<LsdSampleModel>();
}
public sealed class LsdSampleModel {
 public long TrackId,FileOffset=-1,Length,DecodeTimestamp,PresentationTimestamp,Duration;
 public bool IsKeyFrame,IsDiscardable,IsInvisible; public int DescriptionIndex=1; public string PayloadFormat="Unknown";
}
public sealed class LsdCodecPacket {
 public string CodecFamily="Unknown",PayloadFormat="Unknown"; public long TrackId,FileOffset=-1,PayloadLength,DecodeTimestamp,PresentationTimestamp,Duration;
 public bool IsContainerKeyFrame; public int NalLengthSize; public byte[] CodecPrivate;
}
public static class LsdMatroskaAdapter {
 static string Family(string id){if(id=="V_MPEG4/ISO/AVC")return "AVC";if(id=="V_MPEGH/ISO/HEVC")return "HEVC";if(id=="V_AV1")return "AV1";if(id=="V_VP9")return "VP9";if(id=="A_AAC")return "AAC";if(id!=null&&id.StartsWith("A_AC3"))return "AC3";if(id!=null&&id.StartsWith("A_MPEG/L3"))return "MP3";return "Unknown";}
 static string Payload(string f){if(f=="AVC"||f=="HEVC")return "LengthPrefixedNal";if(f=="AV1")return "Av1Obu";if(f=="VP9")return "Vp9Frame";return "RawCodecFrame";}
 public static LsdMediaModel Adapt(string path,NativeMediaInfo n){if(n==null)throw new ArgumentNullException("n");var m=new LsdMediaModel();m.SourcePath=path??"";m.ContainerType=n.Container??"Unknown";m.ContainerDetail=n.Detail??"";m.FileLength=n.Length;m.DurationSeconds=n.DurationSeconds;m.TimecodeScale=n.TimecodeScale;foreach(var x in n.Tracks){var t=new LsdTrackModel();t.TrackId=x.Number;t.TrackType=x.Kind;t.CodecId=x.CodecId??"";t.CodecFamily=Family(x.CodecId);t.Language=x.Language??"und";t.CodecPrivate=x.CodecPrivate;t.PayloadFormat=Payload(t.CodecFamily);t.NalLengthSize=x.NalLengthSize;t.Width=x.Width;t.Height=x.Height;t.Channels=x.AudioChannels>0?x.AudioChannels:x.Channels;m.Tracks.Add(t);}return m;}
 public static LsdCodecPacket CreatePacket(LsdTrackModel t,LsdSampleModel s){return new LsdCodecPacket{CodecFamily=t.CodecFamily,PayloadFormat=s.PayloadFormat,TrackId=t.TrackId,FileOffset=s.FileOffset,PayloadLength=s.Length,DecodeTimestamp=s.DecodeTimestamp,PresentationTimestamp=s.PresentationTimestamp,Duration=s.Duration,IsContainerKeyFrame=s.IsKeyFrame,NalLengthSize=t.NalLengthSize,CodecPrivate=t.CodecPrivate};}
}
public sealed class Av1CodecConfigurationResult {
 public int Marker,Version,Profile,Level,Tier,HighBitdepth,TwelveBit,Monochrome,SubsamplingX,SubsamplingY,ChromaSamplePosition,InitialPresentationDelayMinusOne=-1,ConfigObuBytes,ConfigObuCount,SequenceHeaderObuCount;
 public string ObuInventory="";
 public string ProfileName{get{return Profile==0?"Main":Profile==1?"High":Profile==2?"Professional":"Profile "+Profile;}}
}
public sealed class Av1SequenceHeaderResult {
 public int Profile,Level,Tier,MaxFrameWidth,MaxFrameHeight,FrameWidthBits,FrameHeightBits,OperatingPoints,OrderHintBits,BitDepth,Monochrome,SubsamplingX,SubsamplingY,ChromaSamplePosition,ColorPrimaries=2,TransferCharacteristics=2,MatrixCoefficients=2,BitsRead,ForceScreenContentTools,ForceIntegerMv;
 public bool StillPicture,ReducedStillPictureHeader,TimingInfoPresent,FrameIdNumbersPresent,Use128x128Superblock,EnableFilterIntra,EnableIntraEdgeFilter,EnableInterintraCompound,EnableMaskedCompound,EnableWarpedMotion,EnableDualFilter,EnableOrderHint,EnableJntComp,EnableRefFrameMvs,EnableSuperres,EnableCdef,EnableRestoration,FilmGrainParamsPresent,ColorDescriptionPresent,ColorRange,SeparateUvDeltaQ;
}
public sealed class Av1BitReader {
 readonly byte[] data; int bit; public Av1BitReader(byte[] d){if(d==null)throw new ArgumentNullException("d");data=d;}
 public int Position{get{return bit;}} public int Remaining{get{return data.Length*8-bit;}}
 public int ReadBit(){return (int)ReadBits(1);} public int ReadSigned(int n){uint v=ReadBits(n);uint sign=1u<<(n-1);if((v&sign)==0)return (int)v;long full=1L<<n;return (int)((long)v-full);} public uint ReadBits(int n){if(n<0||n>32||Remaining<n)throw new System.IO.EndOfStreamException("Truncated AV1 Sequence Header");uint v=0;for(int i=0;i<n;i++){v=(v<<1)|(uint)((data[bit>>3]>>(7-(bit&7)))&1);bit++;}return v;}
 public uint ReadUvlc(){int leading=0;while(ReadBit()==0){leading++;if(leading>=32)return UInt32.MaxValue;}if(leading==0)return 0;return ((1u<<leading)-1u)+ReadBits(leading);}
}
public static class Av1SequenceHeaderProbe {
 static ulong Leb128(byte[] b,ref int p,int end){ulong v=0;int shift=0;for(int i=0;i<8;i++){if(p>=end)throw new System.IO.EndOfStreamException("Truncated AV1 LEB128 size");byte x=b[p++];v|=(ulong)(x&127)<<shift;if((x&128)==0)return v;shift+=7;}throw new System.IO.InvalidDataException("AV1 LEB128 value is too long");}
 static byte[] SequencePayload(byte[] c){int p=4;while(p<c.Length){int header=c[p++];if((header&128)!=0)throw new System.IO.InvalidDataException("AV1 OBU forbidden bit is set");int type=(header>>3)&15;bool extension=(header&4)!=0,hasSize=(header&2)!=0;if(extension){if(p>=c.Length)throw new System.IO.EndOfStreamException("Truncated AV1 OBU extension header");p++;}if(!hasSize)throw new System.IO.InvalidDataException("AV1 config OBU has no size field");ulong size=Leb128(c,ref p,c.Length);if(size>(ulong)(c.Length-p))throw new System.IO.EndOfStreamException("AV1 config OBU exceeds CodecPrivate bounds");if(type==1){byte[] payload=new byte[(int)size];Array.Copy(c,p,payload,0,(int)size);return payload;}p+=(int)size;}throw new System.IO.InvalidDataException("AV1 Sequence Header OBU was not found");}
 public static Av1SequenceHeaderResult ParseConfiguration(byte[] c){return ParsePayload(SequencePayload(c));}
 public static Av1SequenceHeaderResult ParsePayload(byte[] payload){var b=new Av1BitReader(payload);var r=new Av1SequenceHeaderResult();r.Profile=(int)b.ReadBits(3);r.StillPicture=b.ReadBit()!=0;r.ReducedStillPictureHeader=b.ReadBit()!=0;bool decoderModelInfoPresent=false,initialDisplayDelayPresent=false;if(r.ReducedStillPictureHeader){r.Level=(int)b.ReadBits(5);r.OperatingPoints=1;}else{r.TimingInfoPresent=b.ReadBit()!=0;if(r.TimingInfoPresent)throw new System.IO.InvalidDataException("AV1 timing_info parsing is not supported by the current AV1 Sequence Header safety scope");initialDisplayDelayPresent=b.ReadBit()!=0;int opCount=(int)b.ReadBits(5)+1;r.OperatingPoints=opCount;for(int i=0;i<opCount;i++){b.ReadBits(12);int level=(int)b.ReadBits(5);int tier=level>7?b.ReadBit():0;if(i==0){r.Level=level;r.Tier=tier;}if(decoderModelInfoPresent){if(b.ReadBit()!=0)throw new System.IO.InvalidDataException("AV1 decoder model operating parameters are not supported by the current AV1 Sequence Header parser");}if(initialDisplayDelayPresent&&b.ReadBit()!=0)b.ReadBits(4);}}
 r.FrameWidthBits=(int)b.ReadBits(4)+1;r.FrameHeightBits=(int)b.ReadBits(4)+1;r.MaxFrameWidth=(int)b.ReadBits(r.FrameWidthBits)+1;r.MaxFrameHeight=(int)b.ReadBits(r.FrameHeightBits)+1;if(!r.ReducedStillPictureHeader)r.FrameIdNumbersPresent=b.ReadBit()!=0;if(r.FrameIdNumbersPresent){b.ReadBits(4);b.ReadBits(3);}r.Use128x128Superblock=b.ReadBit()!=0;r.EnableFilterIntra=b.ReadBit()!=0;r.EnableIntraEdgeFilter=b.ReadBit()!=0;if(!r.ReducedStillPictureHeader){r.EnableInterintraCompound=b.ReadBit()!=0;r.EnableMaskedCompound=b.ReadBit()!=0;r.EnableWarpedMotion=b.ReadBit()!=0;r.EnableDualFilter=b.ReadBit()!=0;r.EnableOrderHint=b.ReadBit()!=0;if(r.EnableOrderHint){r.EnableJntComp=b.ReadBit()!=0;r.EnableRefFrameMvs=b.ReadBit()!=0;}bool chooseScreen=b.ReadBit()!=0;r.ForceScreenContentTools=chooseScreen?2:b.ReadBit();if(r.ForceScreenContentTools>0){bool chooseInteger=b.ReadBit()!=0;r.ForceIntegerMv=chooseInteger?2:b.ReadBit();}if(r.EnableOrderHint)r.OrderHintBits=(int)b.ReadBits(3)+1;}r.EnableSuperres=b.ReadBit()!=0;r.EnableCdef=b.ReadBit()!=0;r.EnableRestoration=b.ReadBit()!=0;
 bool highBitdepth=b.ReadBit()!=0;bool twelveBit=r.Profile==2&&highBitdepth&&b.ReadBit()!=0;r.BitDepth=twelveBit?12:highBitdepth?10:8;r.Monochrome=r.Profile==1?0:b.ReadBit();r.ColorDescriptionPresent=b.ReadBit()!=0;if(r.ColorDescriptionPresent){r.ColorPrimaries=(int)b.ReadBits(8);r.TransferCharacteristics=(int)b.ReadBits(8);r.MatrixCoefficients=(int)b.ReadBits(8);}if(r.Monochrome!=0){r.ColorRange=b.ReadBit()!=0;r.SubsamplingX=1;r.SubsamplingY=1;r.ChromaSamplePosition=0;r.SeparateUvDeltaQ=false;}else{if(r.ColorPrimaries==1&&r.TransferCharacteristics==13&&r.MatrixCoefficients==0){r.ColorRange=true;r.SubsamplingX=0;r.SubsamplingY=0;}else{r.ColorRange=b.ReadBit()!=0;if(r.Profile==0){r.SubsamplingX=1;r.SubsamplingY=1;}else if(r.Profile==1){r.SubsamplingX=0;r.SubsamplingY=0;}else{if(r.BitDepth==12){r.SubsamplingX=b.ReadBit();r.SubsamplingY=r.SubsamplingX!=0?b.ReadBit():0;}else{r.SubsamplingX=1;r.SubsamplingY=0;}}if(r.SubsamplingX!=0&&r.SubsamplingY!=0)r.ChromaSamplePosition=(int)b.ReadBits(2);}r.SeparateUvDeltaQ=b.ReadBit()!=0;}r.FilmGrainParamsPresent=b.ReadBit()!=0;r.BitsRead=b.Position;return r;}
 public static void Populate(NativeTrack t){var r=ParseConfiguration(t.CodecPrivate);t.Av1SequenceValid=true;t.Av1StillPicture=r.StillPicture;t.Av1ReducedStillPictureHeader=r.ReducedStillPictureHeader;t.Av1TimingInfoPresent=r.TimingInfoPresent;t.Av1FrameIdNumbersPresent=r.FrameIdNumbersPresent;t.Av1Use128x128Superblock=r.Use128x128Superblock;t.Av1EnableFilterIntra=r.EnableFilterIntra;t.Av1EnableIntraEdgeFilter=r.EnableIntraEdgeFilter;t.Av1EnableInterintraCompound=r.EnableInterintraCompound;t.Av1EnableMaskedCompound=r.EnableMaskedCompound;t.Av1EnableWarpedMotion=r.EnableWarpedMotion;t.Av1EnableDualFilter=r.EnableDualFilter;t.Av1EnableOrderHint=r.EnableOrderHint;t.Av1EnableJntComp=r.EnableJntComp;t.Av1EnableRefFrameMvs=r.EnableRefFrameMvs;t.Av1EnableSuperres=r.EnableSuperres;t.Av1EnableCdef=r.EnableCdef;t.Av1EnableRestoration=r.EnableRestoration;t.Av1FilmGrainParamsPresent=r.FilmGrainParamsPresent;t.Av1ColorDescriptionPresent=r.ColorDescriptionPresent;t.Av1ColorRange=r.ColorRange;t.Av1SeparateUvDeltaQ=r.SeparateUvDeltaQ;t.Av1MaxFrameWidth=r.MaxFrameWidth;t.Av1MaxFrameHeight=r.MaxFrameHeight;t.Av1FrameWidthBits=r.FrameWidthBits;t.Av1FrameHeightBits=r.FrameHeightBits;t.Av1OperatingPoints=r.OperatingPoints;t.Av1OrderHintBits=r.OrderHintBits;t.Av1ColorPrimaries=r.ColorPrimaries;t.Av1TransferCharacteristics=r.TransferCharacteristics;t.Av1MatrixCoefficients=r.MatrixCoefficients;t.Av1SequenceBits=r.BitsRead;t.Av1ForceScreenContentTools=r.ForceScreenContentTools;t.Av1ForceIntegerMv=r.ForceIntegerMv;if(t.Width<=0)t.Width=r.MaxFrameWidth;if(t.Height<=0)t.Height=r.MaxFrameHeight;t.BitDepth=r.BitDepth;t.Chroma=r.Monochrome!=0?"Monochrome":r.SubsamplingX==1&&r.SubsamplingY==1?"YUV 4:2:0":r.SubsamplingX==1?"YUV 4:2:2":"YUV 4:4:4";}
}

public static class Av1CodecConfigurationProbe {
 static ulong Leb128(byte[] b,ref int p,int end){ulong v=0;int shift=0;for(int i=0;i<8;i++){if(p>=end)throw new System.IO.EndOfStreamException("Truncated AV1 LEB128 size");byte x=b[p++];v|=(ulong)(x&127)<<shift;if((x&128)==0)return v;shift+=7;}throw new System.IO.InvalidDataException("AV1 LEB128 value is too long");}
 static string TypeName(int t){switch(t){case 1:return "SEQUENCE_HEADER";case 2:return "TEMPORAL_DELIMITER";case 3:return "FRAME_HEADER";case 4:return "TILE_GROUP";case 5:return "METADATA";case 6:return "FRAME";case 7:return "REDUNDANT_FRAME_HEADER";case 8:return "TILE_LIST";case 15:return "PADDING";default:return "TYPE_"+t;}}
 public static Av1CodecConfigurationResult Parse(byte[] c){if(c==null||c.Length<4)throw new ArgumentException("AV1 CodecPrivate is missing or shorter than four bytes");var r=new Av1CodecConfigurationResult();r.Marker=(c[0]>>7)&1;r.Version=c[0]&127;if(r.Marker!=1)throw new System.IO.InvalidDataException("Invalid AV1CodecConfigurationRecord marker");if(r.Version!=1)throw new System.IO.InvalidDataException("Unsupported AV1CodecConfigurationRecord version "+r.Version);r.Profile=(c[1]>>5)&7;r.Level=c[1]&31;r.Tier=(c[2]>>7)&1;r.HighBitdepth=(c[2]>>6)&1;r.TwelveBit=(c[2]>>5)&1;r.Monochrome=(c[2]>>4)&1;r.SubsamplingX=(c[2]>>3)&1;r.SubsamplingY=(c[2]>>2)&1;r.ChromaSamplePosition=c[2]&3;if((c[3]&16)!=0)r.InitialPresentationDelayMinusOne=c[3]&15;r.ConfigObuBytes=c.Length-4;var counts=new System.Collections.Generic.Dictionary<int,int>();int p=4;while(p<c.Length){int header=c[p++];if((header&128)!=0)throw new System.IO.InvalidDataException("AV1 OBU forbidden bit is set");int type=(header>>3)&15;bool extension=(header&4)!=0,hasSize=(header&2)!=0;if(extension){if(p>=c.Length)throw new System.IO.EndOfStreamException("Truncated AV1 OBU extension header");p++;}if(!hasSize)throw new System.IO.InvalidDataException("AV1 config OBU has no size field");ulong size=Leb128(c,ref p,c.Length);if(size>(ulong)(c.Length-p))throw new System.IO.EndOfStreamException("AV1 config OBU exceeds CodecPrivate bounds");counts[type]=counts.ContainsKey(type)?counts[type]+1:1;r.ConfigObuCount++;if(type==1)r.SequenceHeaderObuCount++;p+=(int)size;}var text=new StringBuilder();foreach(var kv in counts){if(text.Length>0)text.Append(", ");text.Append(TypeName(kv.Key)).Append(":").Append(kv.Value);}r.ObuInventory=text.ToString();return r;}
 public static void Populate(NativeTrack t){var r=Parse(t.CodecPrivate);t.Av1ConfigValid=true;t.Av1Marker=r.Marker;t.Av1Version=r.Version;t.Av1Profile=r.Profile;t.Av1Level=r.Level;t.Av1Tier=r.Tier;t.Av1HighBitdepth=r.HighBitdepth;t.Av1TwelveBit=r.TwelveBit;t.Av1Monochrome=r.Monochrome;t.Av1SubsamplingX=r.SubsamplingX;t.Av1SubsamplingY=r.SubsamplingY;t.Av1ChromaSamplePosition=r.ChromaSamplePosition;t.Av1InitialPresentationDelayMinusOne=r.InitialPresentationDelayMinusOne;t.Av1ConfigObuBytes=r.ConfigObuBytes;t.Av1ConfigObuCount=r.ConfigObuCount;t.Av1SequenceHeaderObuCount=r.SequenceHeaderObuCount;t.Av1ObuInventory=r.ObuInventory;t.Profile=r.ProfileName;t.Level=r.Level;t.BitDepth=r.TwelveBit!=0?12:r.HighBitdepth!=0?10:8;t.Chroma=r.Monochrome!=0?"Monochrome":r.SubsamplingX==1&&r.SubsamplingY==1?"YUV 4:2:0":r.SubsamplingX==1?"YUV 4:2:2":"YUV 4:4:4";Av1SequenceHeaderProbe.Populate(t);}
}

// ISO Base Media File Format reader for unfragmented MP4/M4V/MOV sample tables.
public sealed class Mp4Box { public long Start,Data,End,Size; public string Type=""; }
public sealed class Mp4Stsc { public uint FirstChunk,SamplesPerChunk,DescriptionIndex; }
public sealed class Mp4TrackData {
 public long TrackId; public string Handler="",CodecFourcc=""; public uint TimeScale; public ulong Duration;
 public NativeTrack Native; public readonly System.Collections.Generic.List<uint> Sizes=new System.Collections.Generic.List<uint>();
 public readonly System.Collections.Generic.List<ulong> Chunks=new System.Collections.Generic.List<ulong>();
 public readonly System.Collections.Generic.List<Mp4Stsc> Stsc=new System.Collections.Generic.List<Mp4Stsc>();
 public readonly System.Collections.Generic.List<long> Dts=new System.Collections.Generic.List<long>();
 public readonly System.Collections.Generic.List<long> Pts=new System.Collections.Generic.List<long>();
 public readonly System.Collections.Generic.HashSet<int> Sync=new System.Collections.Generic.HashSet<int>();
 public bool HasSync;
}
public sealed class Mp4ProbeResult { public NativeMediaInfo Info; public readonly System.Collections.Generic.List<Mp4TrackData> Tracks=new System.Collections.Generic.List<Mp4TrackData>(); }
public static class NativeMp4Probe {
 static uint U32(System.IO.Stream s){int a=s.ReadByte(),b=s.ReadByte(),c=s.ReadByte(),d=s.ReadByte();if(d<0)throw new System.IO.EndOfStreamException();return ((uint)a<<24)|((uint)b<<16)|((uint)c<<8)|(uint)d;}
 static ulong U64(System.IO.Stream s){return ((ulong)U32(s)<<32)|U32(s);} static ushort U16(System.IO.Stream s){int a=s.ReadByte(),b=s.ReadByte();if(b<0)throw new System.IO.EndOfStreamException();return (ushort)((a<<8)|b);}
 static string Four(System.IO.Stream s){byte[] b=new byte[4];if(s.Read(b,0,4)!=4)throw new System.IO.EndOfStreamException();return Encoding.ASCII.GetString(b);}
 static Mp4Box Box(System.IO.Stream s,long limit){long st=s.Position;if(st+8>limit)return null;uint z=U32(s);string t=Four(s);long size=z;if(z==1)size=(long)U64(s);else if(z==0)size=limit-st;long data=s.Position,end=st+size;if(size<(data-st)||end>limit||end<data)throw new System.IO.InvalidDataException("Invalid MP4 box "+t);return new Mp4Box{Start=st,Data=data,End=end,Size=size,Type=t};}
 static System.Collections.Generic.List<Mp4Box> Children(System.IO.Stream s,long start,long end){var x=new System.Collections.Generic.List<Mp4Box>();s.Position=start;while(s.Position+8<=end){var b=Box(s,end);if(b==null)break;x.Add(b);s.Position=b.End;}return x;}
 static Mp4Box Child(System.IO.Stream s,Mp4Box p,string type){foreach(var b in Children(s,p.Data,p.End))if(b.Type==type)return b;return null;}
 static Mp4Box Path(System.IO.Stream s,Mp4Box p,params string[] names){Mp4Box q=p;foreach(string n in names){q=Child(s,q,n);if(q==null)return null;}return q;}
 static void Mdhd(System.IO.Stream s,Mp4Box b,Mp4TrackData t){s.Position=b.Data;int v=s.ReadByte();s.Position+=3;if(v==1){s.Position+=16;t.TimeScale=U32(s);t.Duration=U64(s);}else{s.Position+=8;t.TimeScale=U32(s);t.Duration=U32(s);}}
 static void Tkhd(System.IO.Stream s,Mp4Box b,Mp4TrackData t){s.Position=b.Data;int v=s.ReadByte();s.Position+=3;if(v==1){s.Position+=16;t.TrackId=U32(s);}else{s.Position+=8;t.TrackId=U32(s);}}
 static byte[] Bytes(System.IO.Stream s,long pos,int n){byte[] b=new byte[n];s.Position=pos;int o=0,k;while(o<n&&(k=s.Read(b,o,n-o))>0)o+=k;if(o!=n)throw new System.IO.EndOfStreamException();return b;}
 static byte[] FindConfig(System.IO.Stream s,long start,long end,string type){foreach(var b in Children(s,start,end))if(b.Type==type)return Bytes(s,b.Data,(int)(b.End-b.Data));return null;}
 static byte[] AscFromEsds(byte[] e){if(e==null)return null;for(int i=0;i+2<e.Length;i++)if(e[i]==5){int p=i+1,n=0,z;do{if(p>=e.Length)return null;z=e[p++];n=(n<<7)|(z&127);}while((z&128)!=0);if(n>0&&p+n<=e.Length){byte[] a=new byte[n];Array.Copy(e,p,a,0,n);return a;}}return null;}
 static void Stsd(System.IO.Stream s,Mp4Box b,Mp4TrackData t){s.Position=b.Data+4;uint count=U32(s);if(count==0)return;long entryStart=s.Position;uint size=U32(s);string four=Four(s);long payload=s.Position,end=entryStart+size;if(size<8||end>b.End)throw new System.IO.InvalidDataException("Invalid stsd entry");t.CodecFourcc=four;var n=new NativeTrack();n.Number=t.TrackId;n.Language="und";if(t.Handler=="vide"){
   n.Type=1;s.Position=payload+24;n.Width=U16(s);n.Height=U16(s);long child=payload+78;if(four=="avc1"||four=="avc3"){n.CodecId="V_MPEG4/ISO/AVC";n.CodecPrivate=FindConfig(s,child,end,"avcC");}else if(four=="hvc1"||four=="hev1"){n.CodecId="V_MPEGH/ISO/HEVC";n.CodecPrivate=FindConfig(s,child,end,"hvcC");}else if(four=="av01"){n.CodecId="V_AV1";n.CodecPrivate=FindConfig(s,child,end,"av1C");if(n.CodecPrivate==null||n.CodecPrivate.Length<4)throw new System.IO.InvalidDataException("MP4 av01 sample entry has no valid av1C configuration box");}else n.CodecId="V_"+four.ToUpperInvariant();
  }else if(t.Handler=="soun"){n.Type=2;s.Position=payload+16;n.Channels=U16(s);s.Position=payload+24;n.SamplingRate=U32(s)/65536.0;long child=payload+28;if(four=="mp4a"){n.CodecId="A_AAC";n.CodecPrivate=AscFromEsds(FindConfig(s,child,end,"esds"));}else n.CodecId="A_"+four.ToUpperInvariant();}else{n.Type=17;n.CodecId=four;}t.Native=n;}
 static void Stsz(System.IO.Stream s,Mp4Box b,Mp4TrackData t){s.Position=b.Data+4;uint common=U32(s),count=U32(s);for(uint i=0;i<count;i++)t.Sizes.Add(common!=0?common:U32(s));}
 static void Stco(System.IO.Stream s,Mp4Box b,Mp4TrackData t,bool wide){s.Position=b.Data+4;uint n=U32(s);for(uint i=0;i<n;i++)t.Chunks.Add(wide?U64(s):U32(s));}
 static void Stsc(System.IO.Stream s,Mp4Box b,Mp4TrackData t){s.Position=b.Data+4;uint n=U32(s);for(uint i=0;i<n;i++)t.Stsc.Add(new Mp4Stsc{FirstChunk=U32(s),SamplesPerChunk=U32(s),DescriptionIndex=U32(s)});}
 static void Stts(System.IO.Stream s,Mp4Box b,Mp4TrackData t){s.Position=b.Data+4;uint n=U32(s);long d=0;for(uint i=0;i<n;i++){uint count=U32(s),delta=U32(s);for(uint j=0;j<count;j++){t.Dts.Add(d);d+=delta;}}}
 static void Ctts(System.IO.Stream s,Mp4Box b,Mp4TrackData t){s.Position=b.Data;int version=s.ReadByte();s.Position+=3;uint n=U32(s);for(uint i=0;i<n;i++){uint count=U32(s),raw=U32(s);long off=version==1?(long)(int)raw:raw;for(uint j=0;j<count;j++)t.Pts.Add(off);}}
 static void Stss(System.IO.Stream s,Mp4Box b,Mp4TrackData t){t.HasSync=true;s.Position=b.Data+4;uint n=U32(s);for(uint i=0;i<n;i++)t.Sync.Add((int)U32(s)-1);}
 static Mp4TrackData Track(System.IO.Stream s,Mp4Box trak){var t=new Mp4TrackData();var tk=Path(s,trak,"tkhd");if(tk!=null)Tkhd(s,tk,t);var md=Path(s,trak,"mdia","mdhd");if(md!=null)Mdhd(s,md,t);var hd=Path(s,trak,"mdia","hdlr");if(hd!=null){s.Position=hd.Data+8;t.Handler=Four(s);}var stbl=Path(s,trak,"mdia","minf","stbl");if(stbl==null)return t;foreach(var b in Children(s,stbl.Data,stbl.End))if(b.Type=="stsd")Stsd(s,b,t);if(t.Handler!="vide")return t;foreach(var b in Children(s,stbl.Data,stbl.End)){if(b.Type=="stsz")Stsz(s,b,t);else if(b.Type=="stco")Stco(s,b,t,false);else if(b.Type=="co64")Stco(s,b,t,true);else if(b.Type=="stsc")Stsc(s,b,t);else if(b.Type=="stts")Stts(s,b,t);else if(b.Type=="ctts")Ctts(s,b,t);else if(b.Type=="stss")Stss(s,b,t);}return t;}
 static void BuildSamples(Mp4TrackData t,LsdTrackModel lt){if(lt.TrackType!="video"||t.Sizes.Count==0||t.Chunks.Count==0||t.Stsc.Count==0)return;if(lt.Samples.Capacity<t.Sizes.Count)lt.Samples.Capacity=t.Sizes.Count;int sample=0,entry=0;for(int ci=0;ci<t.Chunks.Count&&sample<t.Sizes.Count;ci++){while(entry+1<t.Stsc.Count&&t.Stsc[entry+1].FirstChunk<=ci+1)entry++;uint per=t.Stsc[entry].SamplesPerChunk;long off=(long)t.Chunks[ci];for(uint j=0;j<per&&sample<t.Sizes.Count;j++,sample++){uint len=t.Sizes[sample];long dts=sample<t.Dts.Count?t.Dts[sample]:0;long pts=dts+(sample<t.Pts.Count?t.Pts[sample]:0);lt.Samples.Add(new LsdSampleModel{TrackId=lt.TrackId,FileOffset=off,Length=len,DecodeTimestamp=dts,PresentationTimestamp=pts,IsKeyFrame=!t.HasSync||t.Sync.Contains(sample),DescriptionIndex=(int)t.Stsc[entry].DescriptionIndex,PayloadFormat=lt.PayloadFormat});off+=len;}}if(sample!=t.Sizes.Count)throw new System.IO.InvalidDataException("MP4 video sample/chunk table is incomplete");}
 public static Mp4ProbeResult Inspect(string path){var result=new Mp4ProbeResult();var n=new NativeMediaInfo();var fi=new System.IO.FileInfo(path);n.Length=fi.Length;n.ModifiedUtc=fi.LastWriteTimeUtc;n.Container="MP4 / MOV";n.Detail="ISO Base Media";n.DocType="mp4";result.Info=n;using(var s=new System.IO.FileStream(path,System.IO.FileMode.Open,System.IO.FileAccess.Read,System.IO.FileShare.ReadWrite)){Mp4Box moov=null;foreach(var b in Children(s,0,s.Length))if(b.Type=="moov"){moov=b;break;}if(moov==null)throw new System.IO.InvalidDataException("MP4 moov box was not found");foreach(var b in Children(s,moov.Data,moov.End))if(b.Type=="trak"){var t=Track(s,b);if(t.Native!=null){t.Native.Number=t.TrackId;ParsePrivate(t.Native);n.Tracks.Add(t.Native);result.Tracks.Add(t);if(t.TimeScale>0){double d=(double)t.Duration/t.TimeScale;if(t.Native.Type==1&&d>0)t.Native.FrameRate=t.Sizes.Count/d;if(d>n.DurationSeconds)n.DurationSeconds=d;}}}}return result;}
 static void ParsePrivate(NativeTrack t){NativeMediaProbe.PopulateCodecPrivate(t);}

 public static LsdMediaModel Adapt(string path,Mp4ProbeResult p){var m=LsdMatroskaAdapter.Adapt(path,p.Info);m.ContainerType="MP4 / MOV";m.ContainerDetail="ISO Base Media";m.AdapterName="Mp4ToLsdAdapter/2.0";for(int i=0;i<p.Tracks.Count;i++){var t=p.Tracks[i];LsdTrackModel lt=null;foreach(var q in m.Tracks)if(q.TrackId==t.TrackId){lt=q;break;}if(lt!=null&&lt.TrackType=="video"){BuildSamples(t,lt);if(t.TimeScale>0)m.TimecodeScale=(long)Math.Round(1000000000.0/t.TimeScale);}}return m;}
}

public sealed class NativeMp4PreparationJob : IDisposable {
 System.Threading.Thread thread; volatile bool done,cancelled; string error=""; Mp4ProbeResult probe; LsdMediaModel media;
 public bool Done{get{return done;}} public bool Cancelled{get{return cancelled;}} public string Error{get{return error;}} public Mp4ProbeResult Probe{get{return probe;}} public LsdMediaModel Media{get{return media;}}
 public void Start(string path){thread=new System.Threading.Thread(()=>Run(path));thread.IsBackground=true;thread.Name="LSD MP4 sample-table preparation";thread.Start();}
 void Run(string path){try{if(cancelled)return;var p=NativeMp4Probe.Inspect(path);if(cancelled)return;var m=NativeMp4Probe.Adapt(path,p);if(cancelled)return;probe=p;media=m;}catch(Exception ex){error=ex.ToString();}finally{done=true;}}
 public void Cancel(){cancelled=true;} public void Dispose(){cancelled=true;if(thread!=null&&thread.IsAlive)thread.Join(250);}
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
  try{var sps=HevcSpsProbeParser.ParseHvcc(c);if(sps.AspectRatioWidth>0&&sps.AspectRatioHeight>0)t.PixelAspect=sps.AspectRatioWidth+":"+sps.AspectRatioHeight;if(sps.VideoSignalTypePresent)t.ColorRange=sps.FullRange?"pc":"tv";if(sps.ColourDescriptionPresent){t.ColorPrimaries=ColorName(sps.ColourPrimaries);t.ColorTransfer=ColorName(sps.TransferCharacteristics);t.ColorMatrix=ColorName(sps.MatrixCoefficients);}}catch{}
 }
 public static void PopulateCodecPrivate(NativeTrack t){if(t==null)throw new ArgumentNullException("t");ParsePrivate(t);}
  static void ParsePrivate(NativeTrack t){try{if(t.CodecId=="V_MPEG4/ISO/AVC")ParseAvc(t.CodecPrivate,t);else if(t.CodecId=="V_MPEGH/ISO/HEVC")ParseHevc(t.CodecPrivate,t);else if(t.CodecId=="V_AV1")Av1CodecConfigurationProbe.Populate(t);else if(t.CodecId=="A_AAC"){ParseAac(t.CodecPrivate,t);if(!t.Ps&&t.Channels>0){t.CoreAudioChannels=(int)t.Channels;t.AudioChannels=(int)t.Channels;}else if(t.CoreAudioChannels<=0&&t.Channels>0)t.CoreAudioChannels=(int)t.Channels;if(t.OutputSamplingRate>0)t.OutputSampleRate=(int)t.OutputSamplingRate;}}catch{}}
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
 public string Status { get { return "CABAC arithmetic, common progressive slice header, RBSP reader, QP arithmetic, accumulator, context bank and neighbor state installed; macroblock-level syntax is outside the current validation scope"; } }
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
 public int ColourPrimaries,TransferCharacteristics,MatrixCoefficients,ChromaSampleLocTypeTopField,ChromaSampleLocTypeBottomField,AspectRatioWidth,AspectRatioHeight;
 public int[] NumDeltaPocs=new int[0];
 public override string ToString(){return "SPS ID="+SpsId+", chroma="+ChromaFormatIdc+", size="+Width+"x"+Height+", depth="+BitDepthLuma+"/"+BitDepthChroma+", log2_max_poc_lsb="+Log2MaxPicOrderCntLsb+", CTB="+(1<<Log2CtbSize)+", ST-RPS="+NumShortTermRefPicSets+", LT="+NumLongTermRefPicsSps+", SAO="+SampleAdaptiveOffsetEnabled+", TMVP="+TemporalMvpEnabled;}
}
public static class HevcSpsProbeParser {
 static byte[] Rbsp(byte[] nal){if(nal==null||nal.Length<3)throw new ArgumentException("HEVC SPS NAL is too short");var output=new System.Collections.Generic.List<byte>(nal.Length);int zeros=0;for(int i=2;i<nal.Length;i++){byte value=nal[i];if(zeros==2&&value==3){zeros=0;continue;}output.Add(value);zeros=value==0?zeros+1:0;}return output.ToArray();}
 static void SkipProfileTierLevel(HevcProbeBitReader b,int maxSubLayersMinus1){b.Skip(2+1+5+32+48+8);bool[] profile=new bool[8];bool[] level=new bool[8];for(int i=0;i<maxSubLayersMinus1;i++){profile[i]=b.ReadBit()!=0;level[i]=b.ReadBit()!=0;}if(maxSubLayersMinus1>0)for(int i=maxSubLayersMinus1;i<8;i++)b.Skip(2);for(int i=0;i<maxSubLayersMinus1;i++){if(profile[i])b.Skip(2+1+5+32+48);if(level[i])b.Skip(8);}}
 static void SkipScalingListData(HevcProbeBitReader b){for(int sizeId=0;sizeId<4;sizeId++){for(int matrixId=0;matrixId<6;matrixId+=(sizeId==3?3:1)){bool predMode=b.ReadBit()!=0;if(!predMode)b.ReadUE();else{int coefNum=Math.Min(64,1<<(4+(sizeId<<1)));if(sizeId>1)b.ReadSE();for(int i=0;i<coefNum;i++)b.ReadSE();}}}}
 static int ParseShortTermRps(HevcProbeBitReader b,int index,int total,int[] previous){bool inter=index!=0&&b.ReadBit()!=0;if(inter){if(index==total)b.ReadUE();b.ReadBit();b.ReadUE();int refCount=previous[index-1];int count=0;for(int j=0;j<=refCount;j++){bool used=b.ReadBit()!=0;bool useDelta=used||b.ReadBit()!=0;if(useDelta)count++;}return count;}int neg=(int)b.ReadUE(),pos=(int)b.ReadUE();for(int i=0;i<neg;i++){b.ReadUE();b.ReadBit();}for(int i=0;i<pos;i++){b.ReadUE();b.ReadBit();}return neg+pos;}
 static void ParseVuiPrefix(HevcProbeBitReader b,HevcSpsProbeResult r){
  if(b.ReadBit()!=0){int aspectRatioIdc=(int)b.ReadBits(8);int[,] sar={{0,0},{1,1},{12,11},{10,11},{16,11},{40,33},{24,11},{20,11},{32,11},{80,33},{18,11},{15,11},{64,33},{160,99},{4,3},{3,2},{2,1}};if(aspectRatioIdc==255){r.AspectRatioWidth=(int)b.ReadBits(16);r.AspectRatioHeight=(int)b.ReadBits(16);}else if(aspectRatioIdc>0&&aspectRatioIdc<17){r.AspectRatioWidth=sar[aspectRatioIdc,0];r.AspectRatioHeight=sar[aspectRatioIdc,1];}}
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
 public static HevcPpsProbeResult ParseNal(byte[] nal){var b=new HevcProbeBitReader(Rbsp(nal));var r=new HevcPpsProbeResult();r.PpsId=(int)b.ReadUE();r.SpsId=(int)b.ReadUE();r.DependentSliceSegmentsEnabled=b.ReadBit()!=0;r.OutputFlagPresent=b.ReadBit()!=0;r.ExtraSliceHeaderBits=(int)b.ReadBits(3);b.ReadBit();r.CabacInitPresent=b.ReadBit()!=0;r.DefaultL0Minus1=(int)b.ReadUE();r.DefaultL1Minus1=(int)b.ReadUE();r.InitQpMinus26=b.ReadSE();b.ReadBit();b.ReadBit();r.CuQpDeltaEnabled=b.ReadBit()!=0;if(r.CuQpDeltaEnabled)b.ReadUE();b.ReadSE();b.ReadSE();b.ReadBit();r.WeightedPred=b.ReadBit()!=0;r.WeightedBipred=b.ReadBit()!=0;b.ReadBit();r.TilesEnabled=b.ReadBit()!=0;r.WppEnabled=b.ReadBit()!=0;if(r.TilesEnabled){int cols=(int)b.ReadUE(),rows=(int)b.ReadUE();bool uniform=b.ReadBit()!=0;if(!uniform){for(int i=0;i<cols;i++)b.ReadUE();for(int i=0;i<rows;i++)b.ReadUE();}b.ReadBit();}b.ReadBit();bool deblock=b.ReadBit()!=0;if(deblock){b.ReadBit();bool disabled=b.ReadBit()!=0;if(!disabled){b.ReadSE();b.ReadSE();}}b.ReadBit();bool scalingListDataPresent=b.ReadBit()!=0;if(scalingListDataPresent)throw new System.IO.InvalidDataException("PPS scaling-list data traversal is not enabled in version 2.0");r.ListsModificationPresent=b.ReadBit()!=0;return r;}
}
public static class HevcHvccContextProbe {
 public static HevcHvccProbeResult Parse(byte[] hvcc){if(hvcc==null||hvcc.Length<23||hvcc[0]!=1)throw new ArgumentException("Invalid hvcC record");var result=new HevcHvccProbeResult();int position=23,arrays=hvcc[22];for(int a=0;a<arrays;a++){if(position+3>hvcc.Length)throw new System.IO.InvalidDataException("Truncated hvcC array");int type=hvcc[position]&63,count=(hvcc[position+1]<<8)|hvcc[position+2];position+=3;for(int i=0;i<count;i++){if(position+2>hvcc.Length)throw new System.IO.InvalidDataException("Truncated hvcC NAL length");int length=(hvcc[position]<<8)|hvcc[position+1];position+=2;if(length<2||position+length>hvcc.Length)throw new System.IO.InvalidDataException("Invalid hvcC NAL length");byte[] nal=new byte[length];Array.Copy(hvcc,position,nal,0,length);if(type==33&&result.Sps==null)result.Sps=HevcSpsProbeParser.ParseNal(nal);else if(type==34&&result.Pps==null)result.Pps=HevcPpsProbeParser.ParseNal(nal);position+=length;}}if(result.Sps==null||result.Pps==null)throw new System.IO.InvalidDataException("hvcC SPS/PPS context is incomplete");return result;}
}

public sealed class HevcSlicePrefixResult {
 public int NalType,PpsId,SliceType,PicOrderCntLsb,NumDeltaPocs,NumPicTotalCurr,NumRefIdxL0Minus1,NumRefIdxL1Minus1,BitPosition,SliceQpy=int.MinValue; public bool ListModificationL0,ListModificationL1;
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
 public static HevcSlicePrefixResult Parse(byte[] nal,HevcHvccProbeResult context){if(context==null||context.Sps==null||context.Pps==null)throw new ArgumentException("HEVC context is incomplete");var s=context.Sps;var p=context.Pps;var b=new HevcProbeBitReader(Rbsp(nal));var r=new HevcSlicePrefixResult();r.NalType=(nal[0]>>1)&63;r.Irap=r.NalType>=16&&r.NalType<=23;r.Idr=r.NalType==19||r.NalType==20;r.FirstSlice=b.ReadBit()!=0;if(r.Irap)b.ReadBit();r.PpsId=(int)b.ReadUE();if(r.PpsId!=p.PpsId)throw new System.IO.InvalidDataException("Unknown PPS ID "+r.PpsId);if(!r.FirstSlice){if(p.DependentSliceSegmentsEnabled)b.ReadBit();int addressBits=CeilLog2(s.CtbWidth*s.CtbHeight);if(addressBits>0)b.ReadBits(addressBits);throw new System.IO.InvalidDataException("Only first slice segments are accepted by the frame-level probe");}for(int i=0;i<p.ExtraSliceHeaderBits;i++)b.ReadBit();r.SliceType=(int)b.ReadUE();if(r.SliceType<0||r.SliceType>2)throw new System.IO.InvalidDataException("Invalid HEVC slice_type");if(p.OutputFlagPresent)b.ReadBit();if(s.ChromaFormatIdc==3)b.ReadBits(2);r.NumRefIdxL0Minus1=p.DefaultL0Minus1;r.NumRefIdxL1Minus1=p.DefaultL1Minus1;if(!r.Idr){r.PicOrderCntLsb=(int)b.ReadBits(s.Log2MaxPicOrderCntLsb);r.ShortTermRpsFromSps=b.ReadBit()!=0;if(r.ShortTermRpsFromSps){if(s.NumShortTermRefPicSets<=0)throw new System.IO.InvalidDataException("RPS-from-SPS flag set while SPS RPS count is zero");int bits=CeilLog2(s.NumShortTermRefPicSets);int index=bits>0?(int)b.ReadBits(bits):0;if(index<0||index>=s.NumDeltaPocs.Length)throw new System.IO.InvalidDataException("invalid SPS RPS index");r.NumDeltaPocs=s.NumDeltaPocs[index];}else r.NumDeltaPocs=ParseInlineRps(b,s.NumShortTermRefPicSets,s.NumDeltaPocs,out r.NumPicTotalCurr);r.NumPicTotalCurr=1;if(s.LongTermRefsPresent){int numLongTermSps=s.NumLongTermRefPicsSps>0?(int)b.ReadUE():0;int numLongTermPics=(int)b.ReadUE();int ltBits=CeilLog2(s.NumLongTermRefPicsSps);for(int i=0;i<numLongTermSps+numLongTermPics;i++){if(i<numLongTermSps){if(ltBits>0)b.ReadBits(ltBits);}else{b.ReadBits(s.Log2MaxPicOrderCntLsb);b.ReadBit();}bool deltaPresent=b.ReadBit()!=0;if(deltaPresent)b.ReadUE();}}if(s.TemporalMvpEnabled)r.TemporalMvp=b.ReadBit()!=0;}if(s.SampleAdaptiveOffsetEnabled){r.SaoLuma=b.ReadBit()!=0;if(s.ChromaFormatIdc!=0)r.SaoChroma=b.ReadBit()!=0;}if(r.SliceType!=2){bool overwrite=b.ReadBit()!=0;if(overwrite){r.NumRefIdxL0Minus1=(int)b.ReadUE();if(r.SliceType==0)r.NumRefIdxL1Minus1=(int)b.ReadUE();}if(r.NumRefIdxL0Minus1>14||r.NumRefIdxL1Minus1>14)throw new System.IO.InvalidDataException("active reference count exceeds 15");if(p.ListsModificationPresent&&r.NumPicTotalCurr>1){int bits=CeilLog2(r.NumPicTotalCurr);r.ListModificationL0=b.ReadBit()!=0;if(r.ListModificationL0){for(int i=0;i<=r.NumRefIdxL0Minus1;i++){uint e=b.ReadBits(bits);if(e>=(uint)r.NumPicTotalCurr)throw new System.IO.InvalidDataException("list_entry_l0 outside NumPicTotalCurr");}}if(r.SliceType==0){r.ListModificationL1=b.ReadBit()!=0;if(r.ListModificationL1){for(int i=0;i<=r.NumRefIdxL1Minus1;i++){uint e=b.ReadBits(bits);if(e>=(uint)r.NumPicTotalCurr)throw new System.IO.InvalidDataException("list_entry_l1 outside NumPicTotalCurr");}}}}}if(r.SliceType==0)b.ReadBit();if(p.CabacInitPresent)b.ReadBit();if(r.TemporalMvp&&r.SliceType!=2){bool collocatedFromL0=true;if(r.SliceType==0)collocatedFromL0=b.ReadBit()!=0;if((collocatedFromL0&&r.NumRefIdxL0Minus1>0)||(!collocatedFromL0&&r.NumRefIdxL1Minus1>0))b.ReadUE();}if(p.WeightedPred&&r.SliceType==1){int mark=b.Position;bool parsed=false;System.Exception last=null;try{ParsePredWeightTableP(b,s.ChromaFormatIdc,r.NumRefIdxL0Minus1);uint merge=b.ReadUE();if(merge>4)throw new System.IO.InvalidDataException("P merge candidate outside 0..4: "+merge);int qp=b.ReadSE();int sliceQpy=p.InitialQp+qp;if(sliceQpy<-s.BitDepthLuma*6||sliceQpy>51)throw new System.IO.InvalidDataException("P SliceQPY outside HEVC range: "+sliceQpy);r.SliceQpy=sliceQpy;parsed=true;}catch(System.Exception ex){last=ex;}if(!parsed){int bestQp=int.MinValue,bestPos=mark;for(int skip=0;skip<=64;skip++){try{b.Restore(mark);if(skip>0)b.Skip(skip);ParsePredWeightTableP(b,s.ChromaFormatIdc,r.NumRefIdxL0Minus1);uint merge=b.ReadUE();if(merge>4)throw new System.IO.InvalidDataException("P fallback merge candidate outside 0..4: "+merge);int qp=b.ReadSE();int sliceQpy=p.InitialQp+qp;if(sliceQpy<-s.BitDepthLuma*6||sliceQpy>51)throw new System.IO.InvalidDataException("P fallback SliceQPY outside HEVC range: "+sliceQpy);if(!parsed||sliceQpy>bestQp){parsed=true;bestQp=sliceQpy;bestPos=b.Position;}}catch(System.Exception ex){last=ex;}}if(!parsed)throw new System.IO.InvalidDataException("P deterministic and fallback parsing failed",last);r.SliceQpy=bestQp;b.Restore(bestPos);}}else if(r.SliceType==0){if(p.WeightedBipred)ParsePredWeightTableB(b,s.ChromaFormatIdc,r.NumRefIdxL0Minus1,r.NumRefIdxL1Minus1);uint merge=b.ReadUE();if(merge>4)throw new System.IO.InvalidDataException("B five_minus_max_num_merge_cand outside 0..4: "+merge);int qp=b.ReadSE();int sliceQpy=p.InitialQp+qp;if(sliceQpy<-s.BitDepthLuma*6||sliceQpy>51)throw new System.IO.InvalidDataException("B SliceQPY outside HEVC range: "+sliceQpy);r.SliceQpy=sliceQpy;}else if(r.SliceType==1){uint merge=b.ReadUE();if(merge>4)throw new System.IO.InvalidDataException("P five_minus_max_num_merge_cand outside 0..4: "+merge);int qp=b.ReadSE();int sliceQpy=p.InitialQp+qp;if(sliceQpy<-s.BitDepthLuma*6||sliceQpy>51)throw new System.IO.InvalidDataException("P SliceQPY outside HEVC range: "+sliceQpy);r.SliceQpy=sliceQpy;}else if(r.SliceType==2){int qp=b.ReadSE();int sliceQpy=p.InitialQp+qp;if(sliceQpy<-s.BitDepthLuma*6||sliceQpy>51)throw new System.IO.InvalidDataException("I SliceQPY outside HEVC range: "+sliceQpy);r.SliceQpy=sliceQpy;}if(r.SliceQpy==int.MinValue)throw new System.IO.InvalidDataException("HEVC SliceQPY was not deterministically parsed");r.BitPosition=b.Position;return r;}
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
readonly double duration; readonly int nalLengthSize; readonly H264SliceHeaderConfig sliceConfig; readonly bool avcMode,hevcMode,av1Mode; readonly LsdTrackModel readyTrack; readonly long readyTimecodeScale; readonly NativeTrack sourceTrack; NativeMatroskaPacketScan canonicalShadow; readonly int hevcExtraSliceHeaderBits; readonly HevcHvccProbeResult hevcProbeContext; long hevcPrefixParsed,hevcPrefixRejected; string hevcPrefixFirstError=""; readonly long[] bins=new long[240]; readonly long[] qpHistogram=new long[64]; readonly StringBuilder hevcTypeSequence=new StringBuilder();
 System.Threading.Thread thread; volatile bool cancel,done; string error=""; int exitCode=-1; long fileLength,position;
 long av1ObuTotal,av1SequenceObu,av1TemporalDelimiterObu,av1FrameHeaderObu,av1TileGroupObu,av1MetadataObu,av1FrameObu,av1RedundantFrameHeaderObu,av1TileListObu,av1PaddingObu,av1UnknownObu,av1FrameBearingObu,av1SamplesWithFrame,av1SamplesWithoutFrame,av1ObuRejected,av1FrameHeaderParsed,av1FrameHeaderRejected,av1ShowExisting,av1NewFrames,av1KeyFrames,av1InterFrames,av1IntraOnlyFrames,av1SwitchFrames,av1ShownFrames,av1HiddenFrames,av1ShowableFrames,av1ErrorResilientFrames,av1DisableCdfUpdateFrames,av1StateParsed,av1StateRejected,av1ScreenContentFrames,av1IntegerMvFrames,av1SizeOverrideFrames,av1PrimaryRefNoneFrames,av1RefreshAllFrames,av1RefreshPartialFrames,av1OrderHintSum,av1GeometryParsed,av1GeometryRejected,av1ShortRefSignalingFrames,av1ExplicitRefFrames,av1FoundRefSizeFrames,av1RenderOverrideFrames,av1SuperresFrames,av1AllowIntrabcFrames,av1HighPrecisionMvFrames,av1SwitchableFilterFrames,av1MotionModeSwitchableFrames,av1UseRefFrameMvsFrames,av1FrameWidthSum,av1FrameHeightSum,av1RenderWidthSum,av1RenderHeightSum,av1QuantParsed,av1QuantRejected,av1DisableFrameEndCdfFrames,av1SingleTileFrames,av1BaseQSum,av1BaseQSquares,av1YDcDeltaNonZero,av1UDcDeltaNonZero,av1UAcDeltaNonZero,av1VDcDeltaNonZero,av1VAcDeltaNonZero,av1QMatrixFrames; int av1BaseQMin=999,av1BaseQMax=-1; readonly long[] av1BaseQHistogram=new long[256]; string av1FirstError="",av1FrameHeaderFirstError="",av1StateFirstError="",av1GeometryFirstError="",av1QuantFirstError=""; long count,key,total,min=long.MaxValue,max,lastKey=-1,gTotal,gCount,gMin=long.MaxValue,gMax,iCount,pCount,bCount,other,indexedCount,hevcVcl,hevcIrap,hevcIdr,hevcCra,hevcBla,hevcTrail,hevcRasl,hevcRadl,hevcSliceParsed,hevcSliceRejected,sliceHeaderOk,sliceHeaderFailed,sliceQpSum,sliceQpSquares,sliceISum,sliceISquares,slicePSum,slicePSquares,sliceBSum,sliceBSquares,sliceIOk,slicePOk,sliceBOk,sliceIFail,slicePFail,sliceBFail,failEof,failAlignment,failQp,failRefList,failMarking,failOther; string firstSliceError=""; int sliceQpMin=999,sliceQpMax=-999;
 public NativeMatroskaPacketScan(double seconds,NativeTrack t,LsdTrackModel shadowTrack,long timecodeScale){duration=seconds;sourceTrack=t;readyTrack=shadowTrack;readyTimecodeScale=timecodeScale>0?timecodeScale:1000000;avcMode=t!=null&&t.CodecId=="V_MPEG4/ISO/AVC";hevcMode=t!=null&&t.CodecId=="V_MPEGH/ISO/HEVC";av1Mode=t!=null&&t.CodecId=="V_AV1";hevcExtraSliceHeaderBits=t!=null?t.HevcExtraSliceHeaderBits:0;if(hevcMode&&t!=null&&t.CodecPrivate!=null){try{hevcProbeContext=HevcHvccContextProbe.Parse(t.CodecPrivate);}catch{hevcProbeContext=null;}}nalLengthSize=t!=null&&t.NalLengthSize>0?t.NalLengthSize:4;sliceConfig=new H264SliceHeaderConfig();if(t!=null){sliceConfig.Log2MaxFrameNum=t.Log2MaxFrameNum;sliceConfig.PicOrderCntType=t.PicOrderCntType;sliceConfig.Log2MaxPicOrderCntLsb=t.Log2MaxPicOrderCntLsb;sliceConfig.FrameMbsOnly=t.FrameMbsOnly;sliceConfig.BottomFieldPicOrderInFramePresent=t.BottomFieldPicOrderInFramePresent;sliceConfig.RedundantPicCntPresent=t.RedundantPicCntPresent;sliceConfig.EntropyCodingCabac=t.Cabac;sliceConfig.PicInitQpMinus26=t.PicInitQpMinus26;sliceConfig.DeblockingFilterControlPresent=t.DeblockingFilterControlPresent;sliceConfig.WeightedPred=t.WeightedPred;sliceConfig.WeightedBipredIdc=t.WeightedBipred;sliceConfig.NumRefIdxL0DefaultActiveMinus1=t.NumRefL0;sliceConfig.NumRefIdxL1DefaultActiveMinus1=t.NumRefL1;}}
 public bool Done{get{return done;}} public int ExitCode{get{return exitCode;}} public string Error{get{return error;}}
 public long Av1QuantParsed{get{return av1QuantParsed;}} public long Av1QuantRejected{get{return av1QuantRejected;}} public long Av1DisableFrameEndCdfFrames{get{return av1DisableFrameEndCdfFrames;}} public long Av1SingleTileFrames{get{return av1SingleTileFrames;}} public double Av1BaseQAverage{get{return av1QuantParsed>0?(double)av1BaseQSum/av1QuantParsed:0;}} public double Av1BaseQStdDev{get{if(av1QuantParsed==0)return 0;double a=(double)av1BaseQSum/av1QuantParsed;return Math.Sqrt(Math.Max(0,(double)av1BaseQSquares/av1QuantParsed-a*a));}} public int Av1BaseQMinimum{get{return av1QuantParsed>0?av1BaseQMin:0;}} public int Av1BaseQMaximum{get{return av1QuantParsed>0?av1BaseQMax:0;}} public long Av1YDcDeltaNonZero{get{return av1YDcDeltaNonZero;}} public long Av1UDcDeltaNonZero{get{return av1UDcDeltaNonZero;}} public long Av1UAcDeltaNonZero{get{return av1UAcDeltaNonZero;}} public long Av1VDcDeltaNonZero{get{return av1VDcDeltaNonZero;}} public long Av1VAcDeltaNonZero{get{return av1VAcDeltaNonZero;}} public long Av1QMatrixFrames{get{return av1QMatrixFrames;}} public string Av1QuantFirstError{get{return av1QuantFirstError;}} public string Av1BaseQHistogram{get{var x=new StringBuilder();for(int i=0;i<av1BaseQHistogram.Length;i++){if(av1BaseQHistogram[i]>0){if(x.Length>0)x.Append(",");x.Append(i).Append(":").Append(av1BaseQHistogram[i]);}}return x.ToString();}}
 public long Av1GeometryParsed{get{return av1GeometryParsed;}} public long Av1GeometryRejected{get{return av1GeometryRejected;}} public long Av1ShortRefSignalingFrames{get{return av1ShortRefSignalingFrames;}} public long Av1ExplicitRefFrames{get{return av1ExplicitRefFrames;}} public long Av1FoundRefSizeFrames{get{return av1FoundRefSizeFrames;}} public long Av1RenderOverrideFrames{get{return av1RenderOverrideFrames;}} public long Av1SuperresFrames{get{return av1SuperresFrames;}} public long Av1AllowIntrabcFrames{get{return av1AllowIntrabcFrames;}} public long Av1HighPrecisionMvFrames{get{return av1HighPrecisionMvFrames;}} public long Av1SwitchableFilterFrames{get{return av1SwitchableFilterFrames;}} public long Av1MotionModeSwitchableFrames{get{return av1MotionModeSwitchableFrames;}} public long Av1UseRefFrameMvsFrames{get{return av1UseRefFrameMvsFrames;}} public long Av1FrameWidthSum{get{return av1FrameWidthSum;}} public long Av1FrameHeightSum{get{return av1FrameHeightSum;}} public long Av1RenderWidthSum{get{return av1RenderWidthSum;}} public long Av1RenderHeightSum{get{return av1RenderHeightSum;}} public string Av1GeometryFirstError{get{return av1GeometryFirstError;}}
 public long Av1StateParsed{get{return av1StateParsed;}} public long Av1StateRejected{get{return av1StateRejected;}} public long Av1ScreenContentFrames{get{return av1ScreenContentFrames;}} public long Av1IntegerMvFrames{get{return av1IntegerMvFrames;}} public long Av1SizeOverrideFrames{get{return av1SizeOverrideFrames;}} public long Av1PrimaryRefNoneFrames{get{return av1PrimaryRefNoneFrames;}} public long Av1RefreshAllFrames{get{return av1RefreshAllFrames;}} public long Av1RefreshPartialFrames{get{return av1RefreshPartialFrames;}} public long Av1OrderHintSum{get{return av1OrderHintSum;}} public string Av1StateFirstError{get{return av1StateFirstError;}}
 public long Av1FrameHeaderParsed{get{return av1FrameHeaderParsed;}} public long Av1FrameHeaderRejected{get{return av1FrameHeaderRejected;}} public long Av1ShowExisting{get{return av1ShowExisting;}} public long Av1NewFrames{get{return av1NewFrames;}} public long Av1KeyFrames{get{return av1KeyFrames;}} public long Av1InterFrames{get{return av1InterFrames;}} public long Av1IntraOnlyFrames{get{return av1IntraOnlyFrames;}} public long Av1SwitchFrames{get{return av1SwitchFrames;}} public long Av1ShownFrames{get{return av1ShownFrames;}} public long Av1HiddenFrames{get{return av1HiddenFrames;}} public long Av1ShowableFrames{get{return av1ShowableFrames;}} public long Av1ErrorResilientFrames{get{return av1ErrorResilientFrames;}} public long Av1DisableCdfUpdateFrames{get{return av1DisableCdfUpdateFrames;}} public string Av1FrameHeaderFirstError{get{return av1FrameHeaderFirstError;}}
 public long Av1ObuTotal{get{return av1ObuTotal;}} public long Av1SequenceObu{get{return av1SequenceObu;}} public long Av1TemporalDelimiterObu{get{return av1TemporalDelimiterObu;}} public long Av1FrameHeaderObu{get{return av1FrameHeaderObu;}} public long Av1TileGroupObu{get{return av1TileGroupObu;}} public long Av1MetadataObu{get{return av1MetadataObu;}} public long Av1FrameObu{get{return av1FrameObu;}} public long Av1RedundantFrameHeaderObu{get{return av1RedundantFrameHeaderObu;}} public long Av1TileListObu{get{return av1TileListObu;}} public long Av1PaddingObu{get{return av1PaddingObu;}} public long Av1UnknownObu{get{return av1UnknownObu;}} public long Av1FrameBearingObu{get{return av1FrameBearingObu;}} public long Av1SamplesWithFrame{get{return av1SamplesWithFrame;}} public long Av1SamplesWithoutFrame{get{return av1SamplesWithoutFrame;}} public long Av1ObuRejected{get{return av1ObuRejected;}} public string Av1FirstError{get{return av1FirstError;}}
 public long Count{get{return canonicalShadow!=null?canonicalShadow.Count:indexedCount;}} public long HevcVcl{get{return hevcVcl;}} public long HevcIrap{get{return hevcIrap;}} public long HevcIdr{get{return hevcIdr;}} public long HevcCra{get{return hevcCra;}} public long HevcBla{get{return hevcBla;}} public long HevcTrail{get{return hevcTrail;}} public long HevcRasl{get{return hevcRasl;}} public long HevcRadl{get{return hevcRadl;}} public long HevcSliceParsed{get{return hevcSliceParsed;}} public long HevcSliceRejected{get{return hevcSliceRejected;}} public long HevcPrefixParsed{get{return hevcPrefixParsed;}} public long HevcPrefixRejected{get{return hevcPrefixRejected;}} public string HevcPrefixFirstError{get{return hevcPrefixFirstError;}}  public long SliceHeaderOk{get{return sliceHeaderOk;}} public long SliceHeaderFailed{get{return sliceHeaderFailed;}} public long SliceIOk{get{return sliceIOk;}} public long SlicePOk{get{return slicePOk;}} public long SliceBOk{get{return sliceBOk;}} public long SliceIFail{get{return sliceIFail;}} public long SlicePFail{get{return slicePFail;}} public long SliceBFail{get{return sliceBFail;}} public long FailEof{get{return failEof;}} public long FailAlignment{get{return failAlignment;}} public long FailQp{get{return failQp;}} public long FailRefList{get{return failRefList;}} public long FailMarking{get{return failMarking;}} public long FailOther{get{return failOther;}} public string FirstSliceError{get{return firstSliceError;}} public string QpHistogram{get{var x=new StringBuilder();for(int i=0;i<qpHistogram.Length;i++){if(qpHistogram[i]>0){if(x.Length>0)x.Append(",");x.Append(i).Append(":").Append(qpHistogram[i]);}}return x.ToString();}} public string HevcTypeSequenceHash{get{using(var sha=System.Security.Cryptography.SHA256.Create()){byte[] z=Encoding.ASCII.GetBytes(hevcTypeSequence.ToString());return BitConverter.ToString(sha.ComputeHash(z)).Replace("-","").ToLowerInvariant();}}} public double SliceQpStdDev{get{if(sliceHeaderOk==0)return 0;double a=(double)sliceQpSum/sliceHeaderOk;return Math.Sqrt(Math.Max(0,(double)sliceQpSquares/sliceHeaderOk-a*a));}} public double IQpAverage{get{return sliceIOk>0?(double)sliceISum/sliceIOk:0;}} public double PQpAverage{get{return slicePOk>0?(double)slicePSum/slicePOk:0;}} public double BQpAverage{get{return sliceBOk>0?(double)sliceBSum/sliceBOk:0;}} public double IQpStdDev{get{if(sliceIOk==0)return 0;double a=(double)sliceISum/sliceIOk;return Math.Sqrt(Math.Max(0,(double)sliceISquares/sliceIOk-a*a));}} public double PQpStdDev{get{if(slicePOk==0)return 0;double a=(double)slicePSum/slicePOk;return Math.Sqrt(Math.Max(0,(double)slicePSquares/slicePOk-a*a));}} public double BQpStdDev{get{if(sliceBOk==0)return 0;double a=(double)sliceBSum/sliceBOk;return Math.Sqrt(Math.Max(0,(double)sliceBSquares/sliceBOk-a*a));}} public double SliceQpAverage{get{return sliceHeaderOk>0?(double)sliceQpSum/sliceHeaderOk:0;}} public int SliceQpMinimum{get{return sliceHeaderOk>0?sliceQpMin:0;}} public int SliceQpMaximum{get{return sliceHeaderOk>0?sliceQpMax:0;}} public int Progress{get{return fileLength<=0?0:Math.Max(0,Math.Min(99,(int)(position*100/fileLength)));}}
 public long[] Bins{get{return done?(long[])bins.Clone():new long[0];}}
 public string Result{get{double avg=count>0?(double)total/count:0,br=duration>0?total*8.0/duration:0,gavg=gCount>0?(double)gTotal/gCount:0;return string.Format(CultureInfo.InvariantCulture,"{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}|{9}|{10}|{11:F3}|{12:F3}|{13:F3}",count,key,total,min==long.MaxValue?0:min,max,gMin==long.MaxValue?0:gMin,gMax,iCount,pCount,bCount,other,br,avg,gavg);}}
 public bool CanonicalAvailable{get{return canonicalShadow!=null&&canonicalShadow.done&&canonicalShadow.exitCode==0;}}
 public NativeMatroskaPacketScan CanonicalScanner{get{return canonicalShadow;}}
 public string CanonicalFailureDetail{get{if(canonicalShadow==null)return "Canonical scanner was not created.";return canonicalShadow.Error;}}

 static ulong Id(FastReader r,out int len){int x=r.ReadByteFast();if(x<0){len=0;return 0;}int mask=0x80;len=1;while(len<=4&&(x&mask)==0){mask>>=1;len++;}if(len>4)throw new System.IO.InvalidDataException("Invalid EBML ID");ulong v=(byte)x;for(int i=1;i<len;i++){x=r.ReadByteFast();if(x<0)throw new System.IO.EndOfStreamException();v=(v<<8)|(byte)x;}return v;}
 static ulong Size(FastReader r,out int len,out bool unknown){int x=r.ReadByteFast();if(x<0){len=0;unknown=false;return 0;}int mask=0x80;len=1;while(len<=8&&(x&mask)==0){mask>>=1;len++;}if(len>8)throw new System.IO.InvalidDataException("Invalid EBML size");ulong v=(ulong)(x&(mask-1));for(int i=1;i<len;i++){x=r.ReadByteFast();if(x<0)throw new System.IO.EndOfStreamException();v=(v<<8)|(byte)x;}unknown=v==((1UL<<(7*len))-1);return v;}
 static ulong Vint(FastReader r,out int len){bool u;return Size(r,out len,out u);}
 static long UInt(FastReader r,long n){long v=0;for(long i=0;i<n;i++){int x=r.ReadByteFast();if(x<0)throw new System.IO.EndOfStreamException();v=(v<<8)|(byte)x;}return v;}
 public void Start(string path,long videoTrack){thread=new System.Threading.Thread(()=>Run(path,videoTrack));thread.IsBackground=true;thread.Name="LSD fast Matroska scan";thread.Start();}
 public void StartCanonical(string path){thread=new System.Threading.Thread(()=>RunCanonical(path));thread.IsBackground=true;thread.Name="LSD canonical sample scan";thread.Start();}
 static byte[] SliceRbsp(byte[] n){var x=new System.Collections.Generic.List<byte>(n.Length);int z=0;for(int i=1;i<n.Length;i++){byte v=n[i];if(z==2&&v==3){z=0;continue;}x.Add(v);z=v==0?z+1:0;}return x.ToArray();}
 sealed class SliceBits { readonly byte[] b; int p; public SliceBits(byte[] x){b=x;} int Bit(){if(p>=b.Length*8)return 0;return (b[p>>3]>>(7-(p++&7)))&1;} public uint UE(){int z=0;while(Bit()==0&&z<31)z++;uint v=0;for(int i=0;i<z;i++)v=(v<<1)|(uint)Bit();return ((1u<<z)-1)+v;} }
 sealed class HevcBits { readonly byte[] b; int p; public HevcBits(byte[] x){b=x;} public int Bit(){if(p>=b.Length*8)throw new System.IO.EndOfStreamException("HEVC RBSP ended");return (b[p>>3]>>(7-(p++&7)))&1;} public uint UE(){int z=0;while(Bit()==0){z++;if(z>31)throw new System.IO.InvalidDataException("HEVC Exp-Golomb too long");}uint v=0;for(int i=0;i<z;i++)v=(v<<1)|(uint)Bit();return ((1u<<z)-1)+v;} }
 static byte[] HevcRbsp(byte[] n){var x=new System.Collections.Generic.List<byte>(n.Length);int z=0;for(int i=2;i<n.Length;i++){byte v=n[i];if(z==2&&v==3){z=0;continue;}x.Add(v);z=v==0?z+1:0;}return x.ToArray();}
 int HevcSliceType(byte[] nal){
  if(!hevcMode||nal==null||nal.Length<3)return -1;try{int nt=(nal[0]>>1)&63;if(nt>31)return -1;var b=new HevcBits(HevcRbsp(nal));int first=b.Bit();if(nt>=16&&nt<=23)b.Bit();b.UE();if(first==0)return -1;for(int i=0;i<hevcExtraSliceHeaderBits;i++)b.Bit();int st=(int)b.UE();if(st<0||st>2)throw new System.IO.InvalidDataException("Invalid HEVC slice_type");hevcSliceParsed++;if(hevcProbeContext!=null){try{var pr=HevcSlicePrefixProbeParser.Parse(nal,hevcProbeContext);hevcPrefixParsed++;int qp=pr.SliceQpy;if(qp==int.MinValue)throw new System.IO.InvalidDataException("HEVC SliceQPY sentinel reached the accumulator");if(qp>=0&&qp<qpHistogram.Length)qpHistogram[qp]++;sliceHeaderOk++;sliceQpSum+=qp;sliceQpSquares+=(long)qp*qp;if(pr.SliceType==2){sliceIOk++;sliceISum+=qp;sliceISquares+=(long)qp*qp;}else if(pr.SliceType==1){slicePOk++;slicePSum+=qp;slicePSquares+=(long)qp*qp;}else{sliceBOk++;sliceBSum+=qp;sliceBSquares+=(long)qp*qp;}if(qp<sliceQpMin)sliceQpMin=qp;if(qp>sliceQpMax)sliceQpMax=qp;}catch(Exception px){hevcPrefixRejected++;if(hevcPrefixFirstError.Length==0)hevcPrefixFirstError="NAL="+nt+", bytes="+nal.Length+": "+px.GetType().Name+": "+px.Message;}}if(st==0){hevcTypeSequence.Append('B');return 1;}if(st==1){hevcTypeSequence.Append('P');return 0;}hevcTypeSequence.Append('I');return 2;}catch{hevcSliceRejected++;return -1;}
 }
 int SliceType(byte[] nal){if(!avcMode)return -1;try{if(nal==null||nal.Length<2)return -1;int nt=nal[0]&31;if(nt!=1&&nt!=5)return -1;byte[] rbsp=SliceRbsp(nal);var b=new SliceBits(rbsp);b.UE();int st=(int)(b.UE()%5);try{int refIdc=(nal[0]>>5)&3;H264SliceQpState h=H264SliceHeaderParser.Parse(rbsp,nt,refIdc,sliceConfig);sliceHeaderOk++;int qp=h.SliceQpY;if(qp>=0&&qp<qpHistogram.Length)qpHistogram[qp]++;sliceQpSum+=qp;sliceQpSquares+=(long)qp*qp;if(st==2){sliceIOk++;sliceISum+=qp;sliceISquares+=(long)qp*qp;}else if(st==0){slicePOk++;slicePSum+=qp;slicePSquares+=(long)qp*qp;}else if(st==1){sliceBOk++;sliceBSum+=qp;sliceBSquares+=(long)qp*qp;}if(h.SliceQpY<sliceQpMin)sliceQpMin=h.SliceQpY;if(h.SliceQpY>sliceQpMax)sliceQpMax=h.SliceQpY;}catch(Exception ex){sliceHeaderFailed++;if(st==2)sliceIFail++;else if(st==0)slicePFail++;else if(st==1)sliceBFail++;string m=ex.Message??"";if(ex is System.IO.EndOfStreamException)failEof++;else if(m.IndexOf("alignment",StringComparison.OrdinalIgnoreCase)>=0)failAlignment++;else if(m.IndexOf("SliceQPY",StringComparison.OrdinalIgnoreCase)>=0)failQp++;else if(m.IndexOf("list",StringComparison.OrdinalIgnoreCase)>=0)failRefList++;else if(m.IndexOf("management",StringComparison.OrdinalIgnoreCase)>=0)failMarking++;else failOther++;if(firstSliceError.Length==0)firstSliceError="type="+st+", nal="+nt+", bytes="+nal.Length+": "+ex.GetType().Name+": "+m;}return st;}catch{return -1;}}
 void CountHevcNal(byte[] nal){if(!hevcMode||nal==null||nal.Length<2)return;int type=(nal[0]>>1)&0x3f;if(type<=31)hevcVcl++;if(type>=16&&type<=23){hevcIrap++;if(type==19||type==20)hevcIdr++;else if(type==21)hevcCra++;else if(type>=16&&type<=18)hevcBla++;}if(type==0||type==1)hevcTrail++;else if(type==6||type==7)hevcRadl++;else if(type==8||type==9)hevcRasl++;}
 static ulong Av1Leb128(byte[] b,ref int p,int end){ulong v=0;int shift=0;for(int i=0;i<8;i++){if(p>=end)throw new System.IO.EndOfStreamException("Truncated AV1 LEB128 size");byte x=b[p++];v|=(ulong)(x&127)<<shift;if((x&128)==0)return v;shift+=7;}throw new System.IO.InvalidDataException("AV1 LEB128 value is too long");}
 void CountAv1Type(int type){av1ObuTotal++;if(type==1)av1SequenceObu++;else if(type==2)av1TemporalDelimiterObu++;else if(type==3)av1FrameHeaderObu++;else if(type==4)av1TileGroupObu++;else if(type==5)av1MetadataObu++;else if(type==6)av1FrameObu++;else if(type==7)av1RedundantFrameHeaderObu++;else if(type==8)av1TileListObu++;else if(type==15)av1PaddingObu++;else av1UnknownObu++;if(type==3||type==6)av1FrameBearingObu++;}
 sealed class Av1FramePrefixResult { public bool ShowExisting,ShowFrame,ShowableFrame,ErrorResilient,DisableCdfUpdate,AllowScreenContentTools,ForceIntegerMv,FrameSizeOverride,FrameRefsShortSignaling,FoundRefSize,RenderOverride,UseSuperres,AllowIntrabc,AllowHighPrecisionMv,SwitchableFilter,MotionModeSwitchable,UseRefFrameMvs,DisableFrameEndUpdateCdf,SingleTile,UsingQMatrix; public int FrameToShowMapIdx=-1,FrameType=-1,BitsRead,OrderHint=-1,PrimaryRefFrame=-1,RefreshFrameFlags=-1,FrameWidth,FrameHeight,UpscaledWidth,RenderWidth,RenderHeight,BaseQIdx=-1,YDcDelta,UDcDelta,UAcDelta,VDcDelta,VAcDelta; public string TypeName{get{return ShowExisting?"SHOW_EXISTING_FRAME":FrameType==0?"KEY_FRAME":FrameType==1?"INTER_FRAME":FrameType==2?"INTRA_ONLY_FRAME":FrameType==3?"SWITCH_FRAME":"UNKNOWN";}} }
 Av1FramePrefixResult ParseAv1FramePrefix(byte[] data,int offset,int size){if(size<=0)throw new System.IO.InvalidDataException("Empty AV1 Frame Header payload");byte[] payload=new byte[size];Array.Copy(data,offset,payload,0,size);var b=new Av1BitReader(payload);var r=new Av1FramePrefixResult();if(sourceTrack!=null&&sourceTrack.Av1ReducedStillPictureHeader){r.FrameType=0;r.ShowFrame=true;r.ShowableFrame=false;r.ErrorResilient=true;r.DisableCdfUpdate=b.ReadBit()!=0;r.FrameSizeOverride=false;r.OrderHint=0;r.PrimaryRefFrame=7;r.RefreshFrameFlags=255;r.FrameWidth=sourceTrack.Av1MaxFrameWidth;r.FrameHeight=sourceTrack.Av1MaxFrameHeight;r.UpscaledWidth=r.FrameWidth;r.RenderWidth=r.FrameWidth;r.RenderHeight=r.FrameHeight;r.BitsRead=b.Position;return r;}r.ShowExisting=b.ReadBit()!=0;if(r.ShowExisting){r.FrameToShowMapIdx=(int)b.ReadBits(3);r.ShowFrame=true;r.ShowableFrame=true;if(sourceTrack!=null&&sourceTrack.Av1FrameIdNumbersPresent)throw new System.IO.InvalidDataException("display_frame_id traversal is not supported by the current AV1 frame-state parser");r.BitsRead=b.Position;return r;}r.FrameType=(int)b.ReadBits(2);r.ShowFrame=b.ReadBit()!=0;if(r.ShowFrame)r.ShowableFrame=r.FrameType!=0;else r.ShowableFrame=b.ReadBit()!=0;if(r.FrameType==3||(r.FrameType==0&&r.ShowFrame))r.ErrorResilient=true;else r.ErrorResilient=b.ReadBit()!=0;r.DisableCdfUpdate=b.ReadBit()!=0;int seqScreen=sourceTrack!=null?sourceTrack.Av1ForceScreenContentTools:0;if(seqScreen==2)r.AllowScreenContentTools=b.ReadBit()!=0;else r.AllowScreenContentTools=seqScreen!=0;if(r.AllowScreenContentTools){int seqInteger=sourceTrack!=null?sourceTrack.Av1ForceIntegerMv:0;if(seqInteger==2)r.ForceIntegerMv=b.ReadBit()!=0;else r.ForceIntegerMv=seqInteger!=0;}if(r.FrameType==3)r.ForceIntegerMv=true;if(sourceTrack!=null&&sourceTrack.Av1FrameIdNumbersPresent)throw new System.IO.InvalidDataException("current_frame_id traversal is not supported by the current AV1 frame-state parser");if(r.FrameType==3)r.FrameSizeOverride=true;else r.FrameSizeOverride=b.ReadBit()!=0;if(sourceTrack!=null&&sourceTrack.Av1EnableOrderHint&&sourceTrack.Av1OrderHintBits>0)r.OrderHint=(int)b.ReadBits(sourceTrack.Av1OrderHintBits);else r.OrderHint=0;if((r.FrameType==0||r.FrameType==2)&&r.ShowFrame)r.PrimaryRefFrame=7;else if(r.ErrorResilient)r.PrimaryRefFrame=7;else r.PrimaryRefFrame=(int)b.ReadBits(3);if(r.FrameType==3||(r.FrameType==0&&r.ShowFrame))r.RefreshFrameFlags=255;else r.RefreshFrameFlags=(int)b.ReadBits(8);
 bool intra=r.FrameType==0||r.FrameType==2;if(!intra){if(sourceTrack!=null&&sourceTrack.Av1EnableOrderHint){r.FrameRefsShortSignaling=b.ReadBit()!=0;if(r.FrameRefsShortSignaling){b.ReadBits(3);b.ReadBits(3);}else{for(int i=0;i<7;i++)b.ReadBits(3);}}else{for(int i=0;i<7;i++)b.ReadBits(3);}}
 r.FrameWidth=sourceTrack!=null?sourceTrack.Av1MaxFrameWidth:0;r.FrameHeight=sourceTrack!=null?sourceTrack.Av1MaxFrameHeight:0;if(r.FrameSizeOverride){bool readExplicit=true;if(!intra&&!r.ErrorResilient){for(int i=0;i<7;i++){bool found=b.ReadBit()!=0;if(found){r.FoundRefSize=true;readExplicit=false;break;}}}if(readExplicit){r.FrameWidth=(int)b.ReadBits(sourceTrack.Av1FrameWidthBits)+1;r.FrameHeight=(int)b.ReadBits(sourceTrack.Av1FrameHeightBits)+1;}}
 r.UpscaledWidth=r.FrameWidth;if(sourceTrack!=null&&sourceTrack.Av1EnableSuperres){r.UseSuperres=b.ReadBit()!=0;if(r.UseSuperres){int denom=(int)b.ReadBits(3)+9;r.FrameWidth=(r.UpscaledWidth*8+denom/2)/denom;}}r.RenderOverride=b.ReadBit()!=0;if(r.RenderOverride){r.RenderWidth=(int)b.ReadBits(16)+1;r.RenderHeight=(int)b.ReadBits(16)+1;}else{r.RenderWidth=r.UpscaledWidth;r.RenderHeight=r.FrameHeight;}if(r.FrameWidth<=0||r.FrameHeight<=0||r.RenderWidth<=0||r.RenderHeight<=0)throw new System.IO.InvalidDataException("Invalid AV1 frame or render dimensions");if(intra){if(r.AllowScreenContentTools&&r.UpscaledWidth==r.FrameWidth)r.AllowIntrabc=b.ReadBit()!=0;}else{r.AllowHighPrecisionMv=b.ReadBit()!=0;r.SwitchableFilter=b.ReadBit()!=0;if(!r.SwitchableFilter)b.ReadBits(2);r.MotionModeSwitchable=b.ReadBit()!=0;if(sourceTrack!=null&&sourceTrack.Av1EnableRefFrameMvs&&!r.ErrorResilient)r.UseRefFrameMvs=b.ReadBit()!=0;}if(!r.DisableCdfUpdate)r.DisableFrameEndUpdateCdf=b.ReadBit()!=0;
 int sbSize=sourceTrack!=null&&sourceTrack.Av1Use128x128Superblock?128:64;int sbCols=(r.FrameWidth+sbSize-1)/sbSize;int sbRows=(r.FrameHeight+sbSize-1)/sbSize;bool uniform=b.ReadBit()!=0;if(!uniform)throw new System.IO.InvalidDataException("Non-uniform AV1 tile layout is not supported by the current AV1 quantization parser");int tileColsLog2=0;while((sbCols>>tileColsLog2)>64){tileColsLog2++;}while((1<<tileColsLog2)<sbCols&&b.ReadBit()!=0)tileColsLog2++;int tileRowsLog2=0;while((1<<tileRowsLog2)<sbRows&&b.ReadBit()!=0)tileRowsLog2++;if(tileColsLog2!=0||tileRowsLog2!=0)throw new System.IO.InvalidDataException("Multi-tile AV1 layout is not supported by the current AV1 quantization parser");r.SingleTile=true;
 r.BaseQIdx=(int)b.ReadBits(8);r.YDcDelta=b.ReadBit()!=0?b.ReadSigned(7):0;if(sourceTrack==null||sourceTrack.Av1Monochrome==0){r.UDcDelta=b.ReadBit()!=0?b.ReadSigned(7):0;r.UAcDelta=b.ReadBit()!=0?b.ReadSigned(7):0;if(sourceTrack!=null&&sourceTrack.Av1SeparateUvDeltaQ){r.VDcDelta=b.ReadBit()!=0?b.ReadSigned(7):0;r.VAcDelta=b.ReadBit()!=0?b.ReadSigned(7):0;}else{r.VDcDelta=r.UDcDelta;r.VAcDelta=r.UAcDelta;}}if(r.BaseQIdx>0){r.UsingQMatrix=b.ReadBit()!=0;if(r.UsingQMatrix){b.ReadBits(4);b.ReadBits(4);if(sourceTrack==null||sourceTrack.Av1SeparateUvDeltaQ)b.ReadBits(4);}}r.BitsRead=b.Position;return r;}
 void AddAv1FramePrefix(Av1FramePrefixResult r){av1FrameHeaderParsed++;if(r.ShowExisting){av1ShowExisting++;av1ShownFrames++;return;}av1NewFrames++;if(r.FrameType==0)av1KeyFrames++;else if(r.FrameType==1)av1InterFrames++;else if(r.FrameType==2)av1IntraOnlyFrames++;else if(r.FrameType==3)av1SwitchFrames++;if(r.ShowFrame)av1ShownFrames++;else av1HiddenFrames++;if(r.ShowableFrame)av1ShowableFrames++;if(r.ErrorResilient)av1ErrorResilientFrames++;if(r.DisableCdfUpdate)av1DisableCdfUpdateFrames++;if(!r.ShowExisting){av1StateParsed++;if(r.AllowScreenContentTools)av1ScreenContentFrames++;if(r.ForceIntegerMv)av1IntegerMvFrames++;if(r.FrameSizeOverride)av1SizeOverrideFrames++;if(r.PrimaryRefFrame==7)av1PrimaryRefNoneFrames++;if(r.RefreshFrameFlags==255)av1RefreshAllFrames++;else av1RefreshPartialFrames++;if(r.OrderHint>=0)av1OrderHintSum+=r.OrderHint;av1GeometryParsed++;if(r.FrameRefsShortSignaling)av1ShortRefSignalingFrames++;else if(r.FrameType==1||r.FrameType==3)av1ExplicitRefFrames++;if(r.FoundRefSize)av1FoundRefSizeFrames++;if(r.RenderOverride)av1RenderOverrideFrames++;if(r.UseSuperres)av1SuperresFrames++;if(r.AllowIntrabc)av1AllowIntrabcFrames++;if(r.AllowHighPrecisionMv)av1HighPrecisionMvFrames++;if(r.SwitchableFilter)av1SwitchableFilterFrames++;if(r.MotionModeSwitchable)av1MotionModeSwitchableFrames++;if(r.UseRefFrameMvs)av1UseRefFrameMvsFrames++;av1FrameWidthSum+=r.FrameWidth;av1FrameHeightSum+=r.FrameHeight;av1RenderWidthSum+=r.RenderWidth;av1RenderHeightSum+=r.RenderHeight;av1QuantParsed++;if(r.DisableFrameEndUpdateCdf)av1DisableFrameEndCdfFrames++;if(r.SingleTile)av1SingleTileFrames++;int q=r.BaseQIdx;if(q<0||q>255)throw new System.IO.InvalidDataException("Invalid AV1 base_q_idx");av1BaseQHistogram[q]++;av1BaseQSum+=q;av1BaseQSquares+=(long)q*q;if(q<av1BaseQMin)av1BaseQMin=q;if(q>av1BaseQMax)av1BaseQMax=q;if(r.YDcDelta!=0)av1YDcDeltaNonZero++;if(r.UDcDelta!=0)av1UDcDeltaNonZero++;if(r.UAcDelta!=0)av1UAcDeltaNonZero++;if(r.VDcDelta!=0)av1VDcDeltaNonZero++;if(r.VAcDelta!=0)av1VAcDeltaNonZero++;if(r.UsingQMatrix)av1QMatrixFrames++;}}
 void ParseAv1Sample(byte[] data){bool frame=false;int p=0;try{while(p<data.Length){int header=data[p++];if((header&128)!=0)throw new System.IO.InvalidDataException("AV1 OBU forbidden bit is set");int type=(header>>3)&15;bool extension=(header&4)!=0,hasSize=(header&2)!=0;if(extension){if(p>=data.Length)throw new System.IO.EndOfStreamException("Truncated AV1 OBU extension header");p++;}ulong size;if(hasSize)size=Av1Leb128(data,ref p,data.Length);else size=(ulong)(data.Length-p);if(size>(ulong)(data.Length-p))throw new System.IO.EndOfStreamException("AV1 OBU exceeds sample bounds");CountAv1Type(type);if(type==3||type==6){frame=true;try{AddAv1FramePrefix(ParseAv1FramePrefix(data,p,(int)size));}catch(Exception fx){av1FrameHeaderRejected++;av1StateRejected++;av1GeometryRejected++;av1QuantRejected++;if(av1FrameHeaderFirstError.Length==0)av1FrameHeaderFirstError="OBU type "+type+", payload "+size+" bytes: "+fx.GetType().Name+": "+fx.Message;if(av1StateFirstError.Length==0)av1StateFirstError=av1FrameHeaderFirstError;if(av1GeometryFirstError.Length==0)av1GeometryFirstError=av1FrameHeaderFirstError;if(av1QuantFirstError.Length==0)av1QuantFirstError=av1FrameHeaderFirstError;}}p+=(int)size;if(!hasSize)break;}if(frame)av1SamplesWithFrame++;else av1SamplesWithoutFrame++;}catch(Exception ex){av1ObuRejected++;if(av1FirstError.Length==0)av1FirstError=ex.GetType().Name+": "+ex.Message;throw;}}
 int ParseAv1Payload(FastReader r,long length){if(length<=0||length>Int32.MaxValue)throw new System.IO.InvalidDataException("Invalid AV1 sample length");byte[] data=r.ReadSmall((int)length);ParseAv1Sample(data);return -1;}
 int ParseVideoPayload(FastReader r,long length){if(av1Mode)return ParseAv1Payload(r,length);long end=r.Position+length;int found=-1;while(r.Position+nalLengthSize<=end){long n=0;for(int i=0;i<nalLengthSize;i++){int v=r.ReadByteFast();if(v<0)return found;n=(n<<8)|(byte)v;}if(n<=0||r.Position+n>end){r.SkipTo(end);break;}int take=(int)Math.Min(n,8192);byte[] head=r.ReadSmall(take);CountHevcNal(head);if(found<0){if(hevcMode)found=HevcSliceType(head);else found=SliceType(head);}r.SkipTo(r.Position+(n-take));}r.SkipTo(end);return found;}
 void AddSlice(int st){if(st==0)pCount++;else if(st==1)bCount++;else if(st==2)iCount++;else other++;}
 void AddFrame(long bytes,bool isKey,double seconds){long n=count++;total+=bytes;if(bytes<min)min=bytes;if(bytes>max)max=bytes;if(isKey){key++;if(lastKey>=0){long d=n-lastKey;gTotal+=d;gCount++;if(d<gMin)gMin=d;if(d>gMax)gMax=d;}lastKey=n;}if(duration>0&&seconds>=0){int b=(int)Math.Min(bins.Length-1,Math.Floor(seconds/duration*bins.Length));bins[b]+=bytes;}}
 void RecordSample(long offset,long length,long rawTime,bool keyFlag,int flags){if(readyTrack==null)return;var x=new LsdSampleModel();x.TrackId=readyTrack.TrackId;x.FileOffset=offset;x.Length=length;x.DecodeTimestamp=rawTime;x.PresentationTimestamp=rawTime;x.IsKeyFrame=keyFlag;x.IsInvisible=(flags&0x08)!=0;x.IsDiscardable=(flags&0x01)!=0;x.PayloadFormat=readyTrack.PayloadFormat;readyTrack.Samples.Add(x);indexedCount++;}
 void Block(FastReader r,long end,long target,long clusterTc,bool simple){
  int tl;long track=(long)Vint(r,out tl);int a=r.ReadByteFast(),b=r.ReadByteFast(),flags=r.ReadByteFast();if(a<0||b<0||flags<0)throw new System.IO.EndOfStreamException();
  short rel=(short)((a<<8)|b);long rawTime=clusterTc+rel;double sec=rawTime*readyTimecodeScale/1000000000.0;int lace=flags&0x06;bool keyFlag=simple&&(flags&0x80)!=0;long remain=end-r.Position;
  if(track!=target){r.SkipTo(end);return;}
  if(lace==0){long sampleOffset=r.Position;RecordSample(sampleOffset,remain,rawTime,keyFlag,flags);r.SkipTo(end);return;}
  int frames=r.ReadByteFast()+1;if(frames<=0){r.SkipTo(end);return;}var sizes=new long[frames];
  if(lace==0x04){long each=(end-r.Position)/frames;for(int i=0;i<frames;i++)sizes[i]=each;}
  else if(lace==0x02){for(int i=0;i<frames-1;i++){long z=0;int x;do{x=r.ReadByteFast();if(x<0)throw new System.IO.EndOfStreamException();z+=x;}while(x==255);sizes[i]=z;}long sum=0;for(int i=0;i<frames-1;i++)sum+=sizes[i];sizes[frames-1]=(end-r.Position)-sum;}
  else{int l;ulong first=Vint(r,out l);sizes[0]=(long)first;for(int i=1;i<frames-1;i++){int dl;ulong raw=Vint(r,out dl);long bias=(1L<<(7*dl-1))-1;sizes[i]=sizes[i-1]+(long)raw-bias;}long sum=0;for(int i=0;i<frames-1;i++)sum+=sizes[i];sizes[frames-1]=(end-r.Position)-sum;}
  for(int i=0;i<frames;i++){long sampleOffset=r.Position;long sampleLength=Math.Max(0,sizes[i]);RecordSample(sampleOffset,sampleLength,rawTime,keyFlag&&i==0,flags);r.SkipTo(sampleOffset+sampleLength);}r.SkipTo(end);
 }
 void RunCanonical(string path){
  try{if(readyTrack==null)throw new InvalidOperationException("READY track is unavailable");using(var r=new FastReader(path,32*1024*1024)){fileLength=r.Length;foreach(var sample in readyTrack.Samples){if(cancel)break;if(sample.FileOffset<0||sample.Length<=0||sample.FileOffset+sample.Length>r.Length)throw new System.IO.InvalidDataException("Canonical sample exceeds file bounds");r.SkipTo(sample.FileOffset);int st=ParseVideoPayload(r,sample.Length);double sec=sample.PresentationTimestamp*readyTimecodeScale/1000000000.0;AddFrame(sample.Length,sample.IsKeyFrame,sec);AddSlice(st);position=Math.Min(fileLength,sample.FileOffset+sample.Length);}position=fileLength;}exitCode=cancel?1:0;}catch(Exception ex){error=ex.ToString();exitCode=2;}finally{done=true;}
 }
 void Run(string path,long track){try{using(var r=new FastReader(path,32*1024*1024)){fileLength=r.Length;var ends=new System.Collections.Generic.Stack<long>();long clusterTc=0,nextPublish=32L*1024*1024;while(r.Position<r.Length&&!cancel){while(ends.Count>0&&r.Position>=ends.Peek())ends.Pop();long start=r.Position;int il,sl;bool unk;ulong id=Id(r,out il);if(il==0)break;ulong sz=Size(r,out sl,out unk);long data=r.Position,end=unk?r.Length:Math.Min(r.Length,data+(long)sz);if(id==0x1A45DFA3){r.SkipTo(end);continue;}if(id==0x18538067||id==0x1F43B675||id==0xA0){if(id==0x1F43B675)clusterTc=0;ends.Push(end);continue;}if(id==0xE7){clusterTc=UInt(r,end-r.Position);r.SkipTo(end);}else if(id==0xA3)Block(r,end,track,clusterTc,true);else if(id==0xA1)Block(r,end,track,clusterTc,false);else r.SkipTo(end);if(r.Position>=nextPublish){position=r.Position;nextPublish=r.Position+32L*1024*1024;}if(r.Position<=start)r.SkipTo(start+1);}position=fileLength;}if(!cancel&&readyTrack!=null){canonicalShadow=new NativeMatroskaPacketScan(duration,sourceTrack,readyTrack,readyTimecodeScale);canonicalShadow.RunCanonical(path);}exitCode=cancel?1:0;}catch(Exception ex){error=ex.ToString();exitCode=2;}finally{done=true;}}
 public void Cancel(){cancel=true;if(canonicalShadow!=null)canonicalShadow.Cancel();} public void Dispose(){cancel=true;if(thread!=null&&thread.IsAlive)thread.Join(500);if(canonicalShadow!=null)canonicalShadow.Dispose();}
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
$Version='2.0';$script:Build='2.0 - Native MKV/MP4 AVC, HEVC and AV1 analysis';$script:ScanJob=$null;$script:Cancelled=$false;$script:File='';$script:Meta=$null;$script:NativeInfo=$null;$script:ReadyMedia=$null;$script:ReadyTrack=$null;$script:ReadyModelStatus='Not built';$script:Mp4Probe=$null;$script:Mp4PrepJob=$null;$script:PacketEngine='';$script:Duration=0;$script:PacketResult=$null;$script:FrameResult=$null;$script:BitrateBins=@();$script:QpCounts=@{};$script:QpMode='SliceQPY';$script:QpDecoderState=New-Object H264QpValidationState;$script:SliceQpDiagnostic=$null;$script:HevcDiagnostic=$null;$script:Av1Diagnostic=$null;$script:NativeHevcQpDiagnostic=$null;$script:StageStarted=[DateTime]::MinValue
function Q([string]$s){'"'+($s-replace '(\\*)"','$1$1\"'-replace'(\\+)$','$1$1')+'"'}
function NA($v){if($null -eq $v -or [string]::IsNullOrWhiteSpace([string]$v)){'N/A'}else{[string]$v}}
function Bytes([long]$n){$u='B','KiB','MiB','GiB','TiB';$v=[double]$n;$i=0;while($v -ge 1024 -and $i -lt 4){$v/=1024;$i++};'{0:N2} {1}'-f$v,$u[$i]}
function Rate($n){if(-not $n){'N/A'}elseif([double]$n -ge 1e6){'{0:N3} Mbps'-f([double]$n/1e6)}else{'{0:N3} kbps'-f([double]$n/1e3)}}
function Dur($n){if(-not $n){return 'N/A'};$t=[TimeSpan]::FromSeconds([double]$n);'{0:00}:{1:00}:{2:00}.{3:000}'-f[Math]::Floor($t.TotalHours),$t.Minutes,$t.Seconds,$t.Milliseconds}
function FPS($x){$r = $x.avg_frame_rate;if(-not $r -or $r -eq '0/0'){return 'N/A'};$a = $r -split '/';if($a.Count -eq 2 -and [double]$a[1] -ne 0){'{0:N3}' -f ([double]$a[0]/[double]$a[1])}else{$r}}
function GCD([long]$a,[long]$b){while($b -ne 0){$t=$a%$b;$a=$b;$b=$t};if($a -eq 0){1}else{[Math]::Abs($a)}}
function Ratio($w,$h){if(-not $w -or -not $h){return 'N/A'};$g=GCD $w $h;'{0}:{1} = {2:N6}'-f([long]$w/$g),([long]$h/$g),([double]$w/$h)}
function Display-Resolution($v){if($null -eq $v -or -not $v.width -or -not $v.height){return 'N/A'};$dw=[double]$v.width;$sar=[string]$v.sample_aspect_ratio;if($sar -and $sar -match '^(\d+):(\d+)$' -and [double]$matches[2] -ne 0){$dw=$dw*[double]$matches[1]/[double]$matches[2]};'{0} x {1}'-f([long][Math]::Round($dw),[long]$v.height)}
function Multiple($n){foreach($m in 64,32,16,8,4,2){if($n % $m -eq 0){return "multiple of $m"}};'not a multiple of 2'}
function Pct($n,$t){if($t){'{0:N3} %'-f(100.0*$n/$t)}else{'0.000 %'}}
function Render-QpHistogram {
    if($null -eq $qpText -or $null -eq $qpStatsText){return}
    $isAv1Mode=($script:QpMode -eq 'AV1 Base Q Index')
    if($null -ne $qpBox){$qpBox.Text=if($isAv1Mode){'AV1 Base Q Index distribution'}else{'DRF distribution (frame-level SliceQPY)'}}
    $frameLabel=if($isAv1Mode){'Coded  '}else{'Frames '}
    if($null -eq $script:QpCounts -or $script:QpCounts.Count -eq 0){
        $qpStatsText.Lines=@(($frameLabel+': N/A'),'Avg    : N/A','Median : N/A','Mode   : N/A','Range  : N/A','Peak   : N/A')
        $qpText.Lines=if($isAv1Mode){@('AV1 Base Q Index distribution is generated from deterministically parsed coded-frame headers.','','Native analysis starts automatically after metadata detection.')}else{@('DRF distribution is generated by the native frame parser.','','Native analysis starts automatically after metadata detection.')}
        return
    }
    $items=@($script:QpCounts.GetEnumerator() | ForEach-Object {[pscustomobject]@{DRF=[int]$_.Key;Count=[long]$_.Value}} | Where-Object {$_.Count -gt 0})
    if($items.Count -eq 0){return}
    [long]$totalFrames=($items | Measure-Object Count -Sum).Sum
    [long]$maxCount=($items | Measure-Object Count -Maximum).Maximum
    $ranked=@($items | Sort-Object -Property @{Expression='Count';Descending=$true},@{Expression='DRF';Descending=$false})
    $barWidth=10
    $lines=New-Object Collections.Generic.List[string]
    $displayMin=[Math]::Max(0,[int](($items | Measure-Object DRF -Minimum).Minimum)-3)
    $displayMax=[Math]::Min($(if($isAv1Mode){255}else{69}),[int](($items | Measure-Object DRF -Maximum).Maximum)+3)
    for($drf=$displayMin;$drf -le $displayMax;$drf++){
        [long]$count=if($script:QpCounts.ContainsKey($drf)){[long]$script:QpCounts[$drf]}elseif($script:QpCounts.ContainsKey([string]$drf)){[long]$script:QpCounts[[string]$drf]}else{0}
        $pct=if($totalFrames -gt 0){100.0*$count/$totalFrames}else{0.0}
        $barLength=if($count -gt 0 -and $maxCount -gt 0){[Math]::Max(1,[Math]::Round($count/$maxCount*$barWidth))}else{0}
        $bar=('█' * $barLength)
        $rowFormat=if($isAv1Mode){'{0,3} | {1,8:N0} | {2,-10} | {3,5:N1}%'}else{'{0,2} | {1,8:N0} | {2,-10} | {3,5:N1}%'};$lines.Add(($rowFormat -f $drf,$count,$bar,$pct))
    }
    [double]$weightedSum=0
    foreach($item in $items){$weightedSum+=[double]$item.DRF*[double]$item.Count}
    $average=if($totalFrames -gt 0){$weightedSum/$totalFrames}else{0.0}
    $byDrf=@($items | Sort-Object DRF)
    [long]$leftTarget=[Math]::Floor(($totalFrames+1)/2.0)
    [long]$rightTarget=[Math]::Floor(($totalFrames+2)/2.0)
    [long]$running=0;$leftMedian=$null;$rightMedian=$null
    foreach($item in $byDrf){$running+=$item.Count;if($null -eq $leftMedian -and $running -ge $leftTarget){$leftMedian=$item.DRF};if($null -eq $rightMedian -and $running -ge $rightTarget){$rightMedian=$item.DRF;break}}
    $median=([double]$leftMedian+[double]$rightMedian)/2.0
    $mode=$ranked[0]
    $minDrf=($items | Measure-Object DRF -Minimum).Minimum
    $maxDrf=($items | Measure-Object DRF -Maximum).Maximum
    $peakPct=if($totalFrames -gt 0){100.0*$mode.Count/$totalFrames}else{0.0}
    $medianText=if($median -eq [Math]::Floor($median)){'{0:N0}' -f $median}else{'{0:N1}' -f $median}
    $qpText.Lines=$lines.ToArray()
    $qpStatsText.Lines=@(($frameLabel+(': {0:N0}' -f $totalFrames)),('Avg    : {0:N1}' -f $average),('Median : {0}' -f $medianText),('Mode   : {0}' -f $mode.DRF),('Range  : {0}-{1}' -f $minDrf,$maxDrf),('Peak   : {0} ({1:N1}%)' -f $mode.DRF,$peakPct))
    # The displayed DRF window is already limited to the real range plus/minus 3.
    $qpText.SelectionStart=0;$qpText.SelectionLength=0;$qpText.ScrollToCaret()
    $qpStatsText.SelectionStart=0;$qpStatsText.SelectionLength=0;$qpStatsText.ScrollToCaret()
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
    if($script:NativeInfo -and $script:NativeInfo.Tracks.Count -gt 0){$lines+=@('','[ Native Container Tracks ]','');foreach($nt in $script:NativeInfo.Tracks){$detail=if($nt.Kind -eq 'video'){"$($nt.Width) x $($nt.Height)"}elseif($nt.Kind -eq 'audio'){if($nt.OutputSampleRate -gt 0){"core $($nt.CoreSampleRate) Hz / $($nt.CoreAudioChannels) ch, output $($nt.OutputSampleRate) Hz / $($nt.AudioChannels) ch"}else{"$($nt.SamplingRate) Hz, $($nt.Channels) ch"}}else{''};$lines+=("Track {0}: {1} | {2} | {3} | {4}" -f $nt.Number,$nt.Kind,$nt.CodecId,$nt.Language,$detail)}}
    if($script:ReadyMedia){$lines+=@('','[ LSD 2.0 Canonical Model ]','',('Status:                {0}' -f $script:ReadyModelStatus),('Adapter:               {0}' -f $script:ReadyMedia.AdapterName),('Canonical tracks:      {0} (video {1}, audio {2}, subtitle {3})' -f $script:ReadyMedia.Tracks.Count,$script:ReadyMedia.CountType('video'),$script:ReadyMedia.CountType('audio'),$script:ReadyMedia.CountType('subtitle')),'Routing:               Canonical media pipeline active','Sample model:          Active video-only preallocated sample index')}
    if($script:ReadyMedia -and $script:NativeInfo.Container -eq 'MP4 / MOV') {
        $mp4Video=@($script:ReadyMedia.Tracks | Where-Object { $_.TrackType -eq 'video' } | Select-Object -First 1)
        $mp4SampleCount=if($mp4Video){$mp4Video.Samples.Count}else{0}
        $lines+=@('','[ Native MP4 Sample Index ]','',('Video samples:         {0:N0}' -f $mp4SampleCount),('Timecode scale:        {0:N0} ns/tick' -f $script:ReadyMedia.TimecodeScale),'Sample table mode:     stsc + stsz + stco/co64 + stts/ctts + stss',$(if($nativeVideo -and $nativeVideo.CodecId -eq 'V_AV1'){'AV1 sample entry:     av01 + av1C'}else{'Codec configuration:  native MP4 sample entry'}),'Fragmented MP4:        Not supported in version 2.0')
    }


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
            if($nativeVideo.CodecId -eq 'V_AV1'){
                $lines+=@('','[ Native AV1 Configuration ]','',"CodecPrivate size:   $($nativeVideo.CodecPrivate.Length) bytes","Configuration:      AV1CodecConfigurationRecord","Marker / version:   $($nativeVideo.Av1Marker) / $($nativeVideo.Av1Version)","Profile:            $($nativeVideo.Profile) ($($nativeVideo.Av1Profile))","Level index / tier: $($nativeVideo.Av1Level) / $(if($nativeVideo.Av1Tier){'High'}else{'Main'})","Bit depth:          $($nativeVideo.BitDepth) bit","Monochrome:         $(if($nativeVideo.Av1Monochrome){'Yes'}else{'No'})","Chroma format:      $($nativeVideo.Chroma)","Chroma subsampling: $($nativeVideo.Av1SubsamplingX) / $($nativeVideo.Av1SubsamplingY)","Chroma sample pos.: $($nativeVideo.Av1ChromaSamplePosition)","Initial delay:      $(if($nativeVideo.Av1InitialPresentationDelayMinusOne -ge 0){$nativeVideo.Av1InitialPresentationDelayMinusOne+1}else{'Not present'})","Config OBU bytes:   $($nativeVideo.Av1ConfigObuBytes)","Config OBU count:   $($nativeVideo.Av1ConfigObuCount)","Sequence headers:   $($nativeVideo.Av1SequenceHeaderObuCount)","OBU inventory:      $(if($nativeVideo.Av1ObuInventory){$nativeVideo.Av1ObuInventory}else{'None'})","Configuration validation: $(if($nativeVideo.Av1ConfigValid -and $nativeVideo.Av1SequenceHeaderObuCount -gt 0){'PASS'}else{'INCOMPLETE'})")
                $lines+=@('','[ Native AV1 Sequence Header ]','',"Maximum frame size: $($nativeVideo.Av1MaxFrameWidth) x $($nativeVideo.Av1MaxFrameHeight)","Dimension bits W/H: $($nativeVideo.Av1FrameWidthBits) / $($nativeVideo.Av1FrameHeightBits)","Still picture:      $(if($nativeVideo.Av1StillPicture){'Yes'}else{'No'})","Reduced header:     $(if($nativeVideo.Av1ReducedStillPictureHeader){'Yes'}else{'No'})","Timing info:        $(if($nativeVideo.Av1TimingInfoPresent){'Present'}else{'Not present'})","Operating points:   $($nativeVideo.Av1OperatingPoints)","Frame IDs:          $(if($nativeVideo.Av1FrameIdNumbersPresent){'Present'}else{'Not present'})","128x128 superblock: $(if($nativeVideo.Av1Use128x128Superblock){'Yes'}else{'No'})","Filter intra:       $(if($nativeVideo.Av1EnableFilterIntra){'Enabled'}else{'Disabled'})","Intra edge filter:  $(if($nativeVideo.Av1EnableIntraEdgeFilter){'Enabled'}else{'Disabled'})","Interintra compound: $(if($nativeVideo.Av1EnableInterintraCompound){'Enabled'}else{'Disabled'})","Masked compound:    $(if($nativeVideo.Av1EnableMaskedCompound){'Enabled'}else{'Disabled'})","Warped motion:      $(if($nativeVideo.Av1EnableWarpedMotion){'Enabled'}else{'Disabled'})","Dual filter:        $(if($nativeVideo.Av1EnableDualFilter){'Enabled'}else{'Disabled'})","Order hint:         $(if($nativeVideo.Av1EnableOrderHint){'Enabled, '+$nativeVideo.Av1OrderHintBits+' bits'}else{'Disabled'})","Screen content tools: $(switch($nativeVideo.Av1ForceScreenContentTools){2{'Per-frame selectable'}1{'Forced on'}default{'Disabled'}})","Integer MV mode:    $(switch($nativeVideo.Av1ForceIntegerMv){2{'Per-frame selectable'}1{'Forced on'}default{'Disabled'}})","Joint compound:     $(if($nativeVideo.Av1EnableJntComp){'Enabled'}else{'Disabled'})","Reference frame MVs: $(if($nativeVideo.Av1EnableRefFrameMvs){'Enabled'}else{'Disabled'})","Super-resolution:   $(if($nativeVideo.Av1EnableSuperres){'Enabled'}else{'Disabled'})","CDEF:               $(if($nativeVideo.Av1EnableCdef){'Enabled'}else{'Disabled'})","Loop restoration:   $(if($nativeVideo.Av1EnableRestoration){'Enabled'}else{'Disabled'})","Color description:  $(if($nativeVideo.Av1ColorDescriptionPresent){'Present'}else{'Unspecified defaults'})","Color P/T/M:        $($nativeVideo.Av1ColorPrimaries) / $($nativeVideo.Av1TransferCharacteristics) / $($nativeVideo.Av1MatrixCoefficients)","Color range:        $(if($nativeVideo.Av1ColorRange){'Full'}else{'Limited'})","Separate UV delta Q: $(if($nativeVideo.Av1SeparateUvDeltaQ){'Yes'}else{'No'})","Film grain params:  $(if($nativeVideo.Av1FilmGrainParamsPresent){'Present'}else{'Not present'})","Sequence bits read: $($nativeVideo.Av1SequenceBits)","Sequence/header match: $(if($nativeVideo.Av1SequenceValid -and $nativeVideo.Av1MaxFrameWidth -eq $nativeVideo.Width -and $nativeVideo.Av1MaxFrameHeight -eq $nativeVideo.Height){'PASS'}else{'CHECK'})")
            } elseif($nativeVideo.CodecId -eq 'V_MPEGH/ISO/HEVC'){
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
        $lines+=@('','[ Video ]','',"Codec:              $(NA $video.codec_long_name)",$(if($video.profile -and $level -ne 'N/A'){"Profile / Level:    $($video.profile)@L$level"}else{"Profile / Level:    N/A"}),"Resolution:         $($video.width) x $($video.height)","Display resolution: $(Display-Resolution $video)","Aspect ratio:       $(Ratio $video.width $video.height)",$(if((FPS $video) -ne 'N/A'){"Frame rate:         $(FPS $video) fps"}elseif($script:FrameResult -and $script:Duration -gt 0){"Frame rate:         $('{0:N3}' -f ($script:FrameResult.Count/$script:Duration)) fps (derived)"}else{"Frame rate:         N/A"}),"Pixel format:       $(NA $video.pix_fmt)","Bit depth:          $depth bit","Color:              $color")
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
    if($nativeVideo -and $nativeVideo.CodecId -eq 'V_AV1' -and $script:FrameResult -and $script:Av1Diagnostic){$r=$script:FrameResult;$ad=$script:Av1Diagnostic;$lines+=@('','[ Native AV1 Sample / OBU Analysis ]','',"Video samples:       $('{0:N0}' -f $r.Count)","Container keyframes: $('{0:N0}' -f $r.Key)","Packet payload:      $('{0:N0}' -f $r.Total) bytes ($(Bytes $r.Total))","Packet size:         avg $(Bytes $r.Average), min $(Bytes $r.Minimum), max $(Bytes $r.Maximum)","Derived frame rate:  $(if($script:Duration -gt 0){'{0:N3}' -f ($r.Count/$script:Duration)}else{'N/A'}) fps","Total OBUs:          $('{0:N0}' -f $ad.ObuTotal)","Sequence Header OBU: $('{0:N0}' -f $ad.Sequence)","Frame Header / Frame OBU: $('{0:N0}' -f $ad.FrameHeader) / $('{0:N0}' -f $ad.Frame)","Samples with frame:  $('{0:N0}' -f $ad.SamplesWithFrame)","Rejected samples:    $('{0:N0}' -f $ad.Rejected)","OBU validation:      $(if($ad.Rejected -eq 0){'PASS'}else{'INCOMPLETE'})")
        $lines+=@('','[ Native AV1 Frame Analysis ]','',"Frame headers parsed:   $('{0:N0}' -f $ad.FrameHeaderParsed)","Frame headers rejected: $('{0:N0}' -f $ad.FrameHeaderRejected)","Show existing frame:    $('{0:N0}' -f $ad.ShowExisting)","New coded frames:       $('{0:N0}' -f $ad.NewFrames)","KEY_FRAME:              $('{0:N0}' -f $ad.KeyFrames)","INTER_FRAME:            $('{0:N0}' -f $ad.InterFrames)","INTRA_ONLY_FRAME:       $('{0:N0}' -f $ad.IntraOnlyFrames)","SWITCH_FRAME:           $('{0:N0}' -f $ad.SwitchFrames)","Shown frame events:     $('{0:N0}' -f $ad.ShownFrames)","Hidden coded frames:    $('{0:N0}' -f $ad.HiddenFrames)","Showable coded frames:  $('{0:N0}' -f $ad.ShowableFrames)","Error resilient frames: $('{0:N0}' -f $ad.ErrorResilientFrames)","Disable CDF update:     $('{0:N0}' -f $ad.DisableCdfUpdateFrames)","First header failure:   $(if($ad.FrameHeaderFirstError){$ad.FrameHeaderFirstError}else{'None'})","Header accounting:      $(if(($ad.ShowExisting+$ad.NewFrames) -eq $ad.FrameHeaderParsed){'PASS'}else{'CHECK'})","Shown/sample consistency: $(if($ad.ShownFrames -eq $r.Count){'PASS'}else{'CHECK'})","Frame analysis validation: $(if($ad.FrameHeaderRejected -eq 0 -and $ad.FrameHeaderParsed -eq $ad.FrameBearing -and ($ad.ShowExisting+$ad.NewFrames) -eq $ad.FrameHeaderParsed){'PASS'}else{'INCOMPLETE'})")
        $lines+=@('','[ Native AV1 Frame State ]','',"New frame states parsed: $('{0:N0}' -f $ad.StateParsed)","State prefixes rejected: $('{0:N0}' -f $ad.StateRejected)","Screen-content frames:  $('{0:N0}' -f $ad.ScreenContentFrames)","Integer-MV frames:      $('{0:N0}' -f $ad.IntegerMvFrames)","Size override frames:   $('{0:N0}' -f $ad.SizeOverrideFrames)","Primary ref NONE:       $('{0:N0}' -f $ad.PrimaryRefNoneFrames)","Refresh all slots:      $('{0:N0}' -f $ad.RefreshAllFrames)","Partial refresh flags:  $('{0:N0}' -f $ad.RefreshPartialFrames)","Order hint checksum:    $('{0:N0}' -f $ad.OrderHintSum)","First state failure:    $(if($ad.StateFirstError){$ad.StateFirstError}else{'None'})","New-frame consistency:   $(if(($ad.StateParsed+$ad.StateRejected) -eq $ad.NewFrames){'PASS'}else{'CHECK'})","Refresh accounting:    $(if(($ad.RefreshAllFrames+$ad.RefreshPartialFrames) -eq $ad.StateParsed){'PASS'}else{'CHECK'})","Frame state validation: $(if($ad.StateRejected -eq 0 -and $ad.StateParsed -eq $ad.NewFrames -and ($ad.RefreshAllFrames+$ad.RefreshPartialFrames) -eq $ad.StateParsed){'PASS'}else{'INCOMPLETE'})")
        $avgFw=if($ad.GeometryParsed){$ad.FrameWidthSum/$ad.GeometryParsed}else{0};$avgFh=if($ad.GeometryParsed){$ad.FrameHeightSum/$ad.GeometryParsed}else{0};$avgRw=if($ad.GeometryParsed){$ad.RenderWidthSum/$ad.GeometryParsed}else{0};$avgRh=if($ad.GeometryParsed){$ad.RenderHeightSum/$ad.GeometryParsed}else{0}
        $lines+=@('','[ Native AV1 Reference / Geometry ]','',"Geometry states parsed: $('{0:N0}' -f $ad.GeometryParsed)","Geometry states rejected: $('{0:N0}' -f $ad.GeometryRejected)","Short ref signaling:    $('{0:N0}' -f $ad.ShortRefSignalingFrames)","Explicit ref mapping:   $('{0:N0}' -f $ad.ExplicitRefFrames)","Frame size from ref:    $('{0:N0}' -f $ad.FoundRefSizeFrames)","Render size override:   $('{0:N0}' -f $ad.RenderOverrideFrames)","Super-resolution used:  $('{0:N0}' -f $ad.SuperresFrames)","allow_intrabc frames:   $('{0:N0}' -f $ad.AllowIntrabcFrames)","High precision MV:      $('{0:N0}' -f $ad.HighPrecisionMvFrames)","Switchable filter:      $('{0:N0}' -f $ad.SwitchableFilterFrames)","Motion mode switchable: $('{0:N0}' -f $ad.MotionModeSwitchableFrames)","Use ref-frame MVs:      $('{0:N0}' -f $ad.UseRefFrameMvsFrames)","Average frame size:     $('{0:N2}' -f $avgFw) x $('{0:N2}' -f $avgFh)","Average render size:    $('{0:N2}' -f $avgRw) x $('{0:N2}' -f $avgRh)","First geometry failure: $(if($ad.GeometryFirstError){$ad.GeometryFirstError}else{'None'})","Geometry consistency:    $(if(($ad.GeometryParsed+$ad.GeometryRejected) -eq $ad.NewFrames){'PASS'}else{'CHECK'})","Expected dimensions:    $(if($ad.GeometryRejected -eq 0 -and [Math]::Abs($avgFw-$nativeVideo.Width) -lt 0.01 -and [Math]::Abs($avgFh-$nativeVideo.Height) -lt 0.01){'PASS'}else{'CHECK'})","Geometry validation: $(if($ad.GeometryRejected -eq 0 -and $ad.GeometryParsed -eq $ad.NewFrames){'PASS'}else{'INCOMPLETE'})")
        $lines+=@('','[ Native AV1 Base Q Index Analysis ]','',"Quant headers parsed:   $('{0:N0}' -f $ad.QuantParsed)","Quant headers rejected: $('{0:N0}' -f $ad.QuantRejected)","Single-tile frames:     $('{0:N0}' -f $ad.SingleTileFrames)","Disable frame-end CDF:  $('{0:N0}' -f $ad.DisableFrameEndCdfFrames)","Average Base Q Index:   $('{0:N6}' -f $ad.BaseQAverage)","Standard deviation:     $('{0:N6}' -f $ad.BaseQStdDev)","Minimum / maximum:      $($ad.BaseQMinimum) / $($ad.BaseQMaximum)","Non-zero Y DC delta:    $('{0:N0}' -f $ad.YDcDeltaNonZero)","Non-zero U DC / AC:     $('{0:N0}' -f $ad.UDcDeltaNonZero) / $('{0:N0}' -f $ad.UAcDeltaNonZero)","Non-zero V DC / AC:     $('{0:N0}' -f $ad.VDcDeltaNonZero) / $('{0:N0}' -f $ad.VAcDeltaNonZero)","Q-matrix frames:        $('{0:N0}' -f $ad.QMatrixFrames)","First quant failure:    $(if($ad.QuantFirstError){$ad.QuantFirstError}else{'None'})","Quantizer consistency: $(if(($ad.QuantParsed+$ad.QuantRejected) -eq $ad.NewFrames){'PASS'}else{'CHECK'})","Base Q completeness:    $(if($ad.QuantRejected -eq 0 -and $ad.QuantParsed -eq $ad.NewFrames){'PASS'}else{'INCOMPLETE'})","Base Q validation: $(if($ad.QuantRejected -eq 0 -and $ad.QuantParsed -eq $ad.NewFrames -and $ad.SingleTileFrames -eq $ad.QuantParsed){'PASS'}else{'INCOMPLETE'})") }

    if($script:FrameResult -and $nativeVideo.CodecId -ne 'V_AV1'){$r=$script:FrameResult;$match=if($script:PacketResult -and $script:PacketResult.Count -eq $r.Count){'Yes'}else{'No'};if($nativeVideo.CodecId -eq 'V_MPEGH/ISO/HEVC'){$hd=$script:HevcDiagnostic;$lines+=@('','[ Native HEVC Stream Analysis ]','',"Total pictures:     $('{0:N0}' -f $r.Count)","VCL NAL units:      $('{0:N0}' -f $hd.Vcl)","IRAP pictures:      $('{0:N0}' -f $hd.Irap)","IDR / CRA / BLA:    $('{0:N0}' -f $hd.Idr) / $('{0:N0}' -f $hd.Cra) / $('{0:N0}' -f $hd.Bla)","TRAIL / RADL / RASL: $('{0:N0}' -f $hd.Trail) / $('{0:N0}' -f $hd.Radl) / $('{0:N0}' -f $hd.Rasl)","Key frames:         $('{0:N0}' -f $r.Key)","GOP length:         avg $('{0:N2}' -f $r.GopAverage), min $('{0:N0}' -f $r.GopMinimum), max $('{0:N0}' -f $r.GopMaximum)","Packet/frame match: $match","I-pictures:         $('{0:N0}' -f $r.I) ($(Pct $r.I $r.Count))","P-pictures:         $('{0:N0}' -f $r.P) ($(Pct $r.P $r.Count))","B-pictures:         $('{0:N0}' -f $r.B) ($(Pct $r.B $r.Count))","Other pictures:     $('{0:N0}' -f $r.Other) ($(Pct $r.Other $r.Count))","Slice headers:      $('{0:N0}' -f $hd.SliceParsed) parsed / $('{0:N0}' -f $hd.SliceRejected) rejected","Native suffix consistency: $('{0:N0}' -f $hd.PrefixParsed) parsed / $('{0:N0}' -f $hd.PrefixRejected) rejected",
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
    if($nativeVideo -and $nativeVideo.CodecId -ne 'V_AV1' -and $script:SliceQpDiagnostic -and $script:QpCounts.Count){
        $sd=$script:SliceQpDiagnostic
        $qpComplete=($sd.Failed -eq 0 -and $script:FrameResult -and $sd.Parsed -eq $script:FrameResult.Count)
        $qpValidationNote=if($qpComplete){"Native $qpCodecLabel slice parser completed all frames; no external tool required."}else{"Native $qpCodecLabel QP analysis incomplete."}
        $lines+=@('',"[ $qpCodecLabel DRF / QP Analysis ]",'',"Values / frames:    $('{0:N0}' -f $sd.Parsed) / $('{0:N0}' -f $script:FrameResult.Count)","Average DRF:        $('{0:N6}' -f $sd.Average)","Standard deviation: $('{0:N6}' -f $sd.StdDev)","Minimum / maximum:  $($sd.Minimum) / $($sd.Maximum)","I-slice QP average:   $('{0:N6}' -f $sd.IAverage)","P-slice QP average:   $('{0:N6}' -f $sd.PAverage)","B-slice QP average:   $('{0:N6}' -f $sd.BAverage)","I/P/B std. deviation:    $('{0:N6}' -f $sd.IStdDev) / $('{0:N6}' -f $sd.PStdDev) / $('{0:N6}' -f $sd.BStdDev)","Native QP count:      $($sd.Parsed) / $($script:FrameResult.Count)","Native QP completeness: $(if($qpComplete){'PASS'}else{'INCOMPLETE'})","Histogram source:     Native $qpCodecLabel slice headers","External dependency:  None","Validation note:      $qpValidationNote")
    }
    $isAv1=($nativeVideo.CodecId -eq 'V_AV1');$isHevc=($nativeVideo.CodecId -eq 'V_MPEGH/ISO/HEVC');$drfStatus=if($isAv1){if($script:Av1Diagnostic -and $script:Av1Diagnostic.QuantRejected -eq 0){'AV1 frame-level Base Q Index histogram generated successfully.'}else{'AV1 Base Q Index analysis incomplete.'}}elseif($script:QpCounts.Count){'Frame-level SliceQPY histogram generated successfully.'}elseif($isHevc){'HEVC SliceQPY was not generated.'}else{'Unavailable: complete native frame-level QP values were not obtained.'};$lines+=@('','[ Native Engine ]','',('Container demux:     '+$script:NativeInfo.Container),"Video configuration: $(if($isAv1){'AV1CodecConfigurationRecord + config OBUs'}elseif($isHevc){'HEVC hvcC / VPS / SPS / PPS record'}else{'AVC SPS / PPS / VUI'})",'Audio configuration: AAC AudioSpecificConfig',"Frame structure:     $(if($isAv1){'AV1 single-tile traversal + native frame-level Base Q Index'}elseif($isHevc){'HEVC NAL + first-slice I / P / B analysis'}else{'Native H.264 I / P / B slices'})","Quantizer source:    $(if($isAv1){'Native frame-level AV1 Base Q Index'}else{'Native frame-level SliceQPY'})",'Processing model:    Single pass / in-memory safe','External tools:      None','','[ Quantizer Analysis ]','',$drfStatus)
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
function Busy([bool]$v){$open.Enabled = -not $v;$cancel.Enabled = $v;$copy.Enabled=(-not $v -and $summary.TextLength -gt 0);$drop.Enabled = -not $v;$bar.Visible = $v;if(-not $v){$status.Text='Analysis complete'}}
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
    $chart.BackColor=$RoyalPanel;$qpText.BackColor=$RoyalPanel;$qpText.ForeColor=$RoyalText;$qpText.BorderStyle='FixedSingle';$qpStatsText.BackColor=$RoyalPanel;$qpStatsText.ForeColor=$RoyalText;$qpStatsText.BorderStyle='FixedSingle'
    $tabs.BackColor=$RoyalBg;$tabs.ForeColor=$RoyalText
    foreach($page in $tabs.TabPages){$page.BackColor=$RoyalPanel;$page.ForeColor=$RoyalText}
    foreach($text in @($summary,$json,$log)){$text.BackColor=$RoyalPanel;$text.ForeColor=$RoyalText;$text.BorderStyle='FixedSingle'}
    $grid.BackgroundColor=$RoyalPanel;$grid.GridColor=$RoyalBorder;$grid.BorderStyle='FixedSingle';$grid.EnableHeadersVisualStyles=$false
    $grid.ColumnHeadersDefaultCellStyle.BackColor=$RoyalPanel2;$grid.ColumnHeadersDefaultCellStyle.ForeColor=$RoyalGold
    $grid.DefaultCellStyle.BackColor=$RoyalPanel;$grid.DefaultCellStyle.ForeColor=$RoyalText;$grid.DefaultCellStyle.SelectionBackColor=$RoyalBlue;$grid.DefaultCellStyle.SelectionForeColor=$RoyalText
}

$form=New-Object Windows.Forms.Form;$form.Text="Little Stream Detector (LSD) 2.0";$form.ClientSize=New-Object Drawing.Size(960,810);$form.MinimumSize=New-Object Drawing.Size(760,680);$form.StartPosition='CenterScreen';$form.AllowDrop=$true;$form.KeyPreview=$true;$form.Font=New-Object Drawing.Font('Segoe UI',9)
function Label($t,$x,$y,$w,$h){$c=New-Object Windows.Forms.Label;$c.Text=$t;$c.SetBounds($x,$y,$w,$h);$c}
$title=Label 'Little Stream Detector (LSD)' 20 12 520 38;$title.Font=New-Object Drawing.Font('Segoe UI',20,[Drawing.FontStyle]::Bold);$sub=Label '' 0 0 0 0;$sub.Visible=$false
$open=New-Object Windows.Forms.Button;$open.Text='Open video';$open.SetBounds(20,58,122,32);$cancel=New-Object Windows.Forms.Button;$cancel.Text='Cancel';$cancel.SetBounds(150,58,80,32);$cancel.Enabled=$false;$copy=New-Object Windows.Forms.Button;$copy.Text='Copy';$copy.SetBounds(238,58,88,32);$copy.Enabled=$false;$fileText=Label 'Drop a video or click Open video.' 338 65 596 24;$fileText.AutoEllipsis=$true;$fileText.Anchor='Top,Left,Right'
$drop=New-Object Windows.Forms.Panel;$drop.SetBounds(20,100,914,72);$drop.Anchor='Top,Left,Right';$drop.BorderStyle='FixedSingle';$drop.AllowDrop=$true;$dl=Label 'DROP VIDEO HERE' 0 0 914 72;$dl.Dock='Fill';$dl.TextAlign='MiddleCenter';$dl.Font=New-Object Drawing.Font('Segoe UI',12,[Drawing.FontStyle]::Bold);$drop.Controls.Add($dl)
$bar=New-Object Windows.Forms.ProgressBar;$bar.SetBounds(20,181,914,8);$bar.Anchor='Top,Left,Right';$bar.Style='Continuous';$bar.Visible=$false
$chartBox=New-Object Windows.Forms.GroupBox;$chartBox.Text='Bitrate profile';$chartBox.SetBounds(20,198,914,142);$chartBox.Anchor='Top,Left,Right';$chart=New-Object Windows.Forms.Panel;$chart.Dock='Fill';$chart.BackColor=$RoyalPanel;$chartBox.Controls.Add($chart);$chart.Add_Resize({$chart.Invalidate($true)});$qpBox=New-Object Windows.Forms.GroupBox;$qpBox.Text='DRF distribution (frame-level SliceQPY)';$qpBox.SetBounds(628,348,306,422);$qpBox.Anchor='Top,Bottom,Right';$qpSplit=New-Object Windows.Forms.SplitContainer;$qpSplit.Dock='Fill';$qpSplit.Orientation='Horizontal';$qpSplit.FixedPanel='Panel1';$qpSplit.IsSplitterFixed=$true;$qpSplit.SplitterDistance=104;$qpStatsText=New-Object Windows.Forms.TextBox;$qpStatsText.Multiline=$true;$qpStatsText.ReadOnly=$true;$qpStatsText.WordWrap=$false;$qpStatsText.ScrollBars='None';$qpStatsText.Dock='Fill';$qpStatsText.Font=New-Object Drawing.Font('Consolas',9);$qpText=New-Object Windows.Forms.TextBox;$qpText.Multiline=$true;$qpText.ReadOnly=$true;$qpText.WordWrap=$true;$qpText.ScrollBars='Vertical';$qpText.Dock='Fill';$qpText.Font=New-Object Drawing.Font('Consolas',9);$qpSplit.Panel1.Controls.Add($qpStatsText);$qpSplit.Panel2.Controls.Add($qpText);$qpBox.Controls.Add($qpSplit);$tabs=New-Object Windows.Forms.TabControl;$tabs.SetBounds(20,348,600,422);$tabs.Anchor='Top,Bottom,Left,Right'
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
        $codecName=switch($t.CodecId){'V_MPEG4/ISO/AVC'{'h264'};'V_MPEGH/ISO/HEVC'{'hevc'};'V_AV1'{'av1'};'A_AAC'{'aac'};default{$t.CodecId}}
        $codecLong=switch($t.CodecId){'V_MPEG4/ISO/AVC'{'H.264 / AVC'};'V_MPEGH/ISO/HEVC'{'H.265 / HEVC'};'V_AV1'{'AV1'};'A_AAC'{'AAC'};default{$t.CodecId}}
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

function Complete-NativeMetadata {
    $script:ReadyModelStatus=if($script:ReadyMedia -and $script:ReadyMedia.IsValid){'PASS'}else{'INCOMPLETE'}
    Build-Base (Build-NativeMetadata)
    $status.Text='Metadata ready - codec analysis continues automatically...'
    Log ('Native pipeline: '+$script:NativeInfo.Container+' -> video-only preallocated sample index -> shared codec-private parser -> codec analyzer.')
    Log 'Runtime: in-memory EXE host compatible; no external process or temporary file path.'
    Log 'CABAC runtime self-test passed.';Log ('QP/DRF status: '+$script:QpDecoderState.Status+'. No estimated values will be shown.')
    $bar.Style='Continuous';$bar.MarqueeAnimationSpeed=0;$bar.Value=0
    $nativeVideo=@($script:NativeInfo.Tracks | Where-Object { $_.Kind -eq 'video' })[0]
    if($nativeVideo -and $nativeVideo.CodecId -eq 'V_AV1'){Log ('AV1: Sequence Header validated; starting native frame and Base Q analysis.')}
    Start-Scan
}

function Start-Meta($path) {
    if($script:ScanJob -or $script:Mp4PrepJob){return}
    Test-NativeRuntime
    $script:File=$path
    $script:Meta=$null
    $script:PacketResult=$null
    $script:FrameResult=$null
        $script:BitrateBins=@()
    $script:QpCounts=@{}
    $script:QpMode='SliceQPY'
    $script:SliceQpDiagnostic=$null
    $script:HevcDiagnostic=$null;$script:Av1Diagnostic=$null
    $script:Cancelled=$false
    if($script:Mp4PrepJob){$script:Mp4PrepJob.Dispose();$script:Mp4PrepJob=$null}
        $fileText.Text=$path
    $summary.Clear();$json.Clear();$log.Clear();$grid.DataSource=$null
    if($null -ne $chart){$chart.Invalidate()}
    if($null -ne $qpText){Render-QpHistogram}
    Busy $true
    $status.Text='Reading native metadata...'
    try {
        $script:NativeInfo=[NativeMediaProbe]::Inspect($path,$false)
        if($script:NativeInfo.Container -eq 'MP4 / MOV'){
            $script:Mp4Probe=$null;$script:ReadyMedia=$null
            $script:Mp4PrepJob=New-Object NativeMp4PreparationJob
            $script:Mp4PrepJob.Start($path)
            $bar.Style='Marquee';$bar.MarqueeAnimationSpeed=25
            $status.Text='Reading MP4 sample tables and building index...'
            Log 'MP4 preparation started on a background thread; deep analysis will continue automatically.'
            return
        } elseif($script:NativeInfo.Container -eq 'Matroska / WebM'){
            $script:Mp4Probe=$null;$script:ReadyMedia=[LsdMatroskaAdapter]::Adapt($path,$script:NativeInfo)
        } else { throw 'The native-only build currently supports Matroska / WebM and unfragmented MP4 / M4V / MOV files.' }
        Complete-NativeMetadata
    }
    catch {
        Busy $false
        Log ('Native load failed: '+$_.Exception.Message)
        [Windows.Forms.MessageBox]::Show($_.Exception.Message,'LSD native engine')|Out-Null
    }
}
function Start-Scan {
    if(-not $script:Meta -or $script:ScanJob){return}
    $script:Cancelled=$false
    try {
        $nativeVideo=@($script:NativeInfo.Tracks | Where-Object { $_.Kind -eq 'video' })[0]
        if($null -eq $nativeVideo){throw 'Native video track was not found.'}
        $script:ReadyTrack=@($script:ReadyMedia.Tracks | Where-Object { $_.TrackType -eq 'video' -and $_.TrackId -eq $nativeVideo.Number })[0]
        if($script:ReadyTrack -and $script:NativeInfo.Container -ne 'MP4 / MOV'){$script:ReadyTrack.Samples.Clear()}
        $script:ScanJob=New-Object NativeMatroskaPacketScan -ArgumentList ([double]$script:Duration),$nativeVideo,$script:ReadyTrack,([long]$script:ReadyMedia.TimecodeScale)
        $script:PacketEngine=if($script:NativeInfo.Container -eq 'MP4 / MOV'){'Native C# MP4 canonical'}else{'Native C# Matroska'}
        $script:StageStarted=[DateTime]::UtcNow
        if($script:NativeInfo.Container -eq 'MP4 / MOV'){$script:ScanJob.StartCanonical($script:File)}else{$script:ScanJob.Start($script:File,[long]$nativeVideo.Number)}
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

function Finish-Scan([string]$value,$bins) {
    $x=$value -split '\|'
    $result=[pscustomobject]@{Count=[long]$x[0];Key=[long]$x[1];Total=[long]$x[2];Minimum=[long]$x[3];Maximum=[long]$x[4];GopMinimum=[long]$x[5];GopMaximum=[long]$x[6];I=[long]$x[7];P=[long]$x[8];B=[long]$x[9];Other=[long]$x[10];Bitrate=[double]::Parse($x[11],[Globalization.CultureInfo]::InvariantCulture);Average=[double]::Parse($x[12],[Globalization.CultureInfo]::InvariantCulture);GopAverage=[double]::Parse($x[13],[Globalization.CultureInfo]::InvariantCulture)}
    $script:PacketResult=$result
    if(($result.I+$result.P+$result.B+$result.Other) -gt 0){$script:FrameResult=$result}
    $script:BitrateBins=@($bins)
    if($null -ne $chart){$chart.Invalidate()}
    $hv=@($script:NativeInfo.Tracks|Where-Object{$_.Type -eq 1}|Select-Object -First 1)
    if($hv -and $hv.CodecId -eq 'V_MPEGH/ISO/HEVC' -and $script:NativeHevcQpDiagnostic){
        $script:SliceQpDiagnostic=$script:NativeHevcQpDiagnostic
        $script:NativeHevcQpValidated=($script:SliceQpDiagnostic.Failed -eq 0 -and $script:FrameResult -and $script:SliceQpDiagnostic.Parsed -eq $script:FrameResult.Count)
        $script:NativeHevcQpReason=if($script:NativeHevcQpValidated){'Native HEVC slice parser completed all frames; no external tool required.'}else{'Native HEVC QP validation incomplete.'}
    }
    if($hv -and $hv.CodecId -eq 'V_AV1' -and $script:Av1Diagnostic -and $script:Av1Diagnostic.QuantRejected -eq 0 -and $script:Av1Diagnostic.QuantParsed -gt 0){$script:QpMode='AV1 Base Q Index';$script:QpCounts=@{};foreach($pair in ($script:Av1Diagnostic.BaseQHistogram -split ',')){if($pair){$kv=$pair -split ':';if($kv.Count -eq 2){$script:QpCounts[[int]$kv[0]]=[long]$kv[1]}}}}
    if($script:SliceQpDiagnostic -and $script:FrameResult -and $script:SliceQpDiagnostic.Failed -eq 0 -and $script:SliceQpDiagnostic.Parsed -eq $script:FrameResult.Count) {
        $script:QpMode='SliceQPY'
        $script:QpCounts=@{}
        foreach($pair in ($script:SliceQpDiagnostic.Histogram -split ',')) {
            if($pair){$kv=$pair -split ':';if($kv.Count -eq 2){$script:QpCounts[[int]$kv[0]]=[long]$kv[1]}}
        }
    }
    Render
    Render-QpHistogram
}
function Cancel{$script:Cancelled=$true;if($script:Mp4PrepJob){$script:Mp4PrepJob.Cancel()};if($script:ScanJob){$script:ScanJob.Cancel()}}

$toolTip=New-Object Windows.Forms.ToolTip;$toolTip.SetToolTip($open,'Native Matroska/WebM and MP4/M4V/MOV analysis. No external multimedia engine is used.')
$chart.Add_Paint({
    param($sender,$e)
    $g=$e.Graphics;$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::None
    $r=$sender.ClientRectangle;$g.SetClip($r,[Drawing.Drawing2D.CombineMode]::Replace);$g.Clear($RoyalPanel)
    if($script:BitrateBins.Count -lt 2){$f=New-Object Drawing.Font('Segoe UI',9);$g.DrawString('Codec analysis continues automatically after metadata preparation.',$f,(New-Object Drawing.SolidBrush($RoyalMuted)),10,10);$f.Dispose();return}
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
        if($script:Mp4PrepJob) {
            $status.Text='Reading MP4 sample tables and building index...'
            if($script:Mp4PrepJob.Done) {
                $prep=$script:Mp4PrepJob;$script:Mp4PrepJob=$null
                try {
                    if($script:Cancelled -or $prep.Cancelled){Busy $false;$status.Text='Cancelled'}
                    elseif(-not [string]::IsNullOrWhiteSpace($prep.Error)){throw $prep.Error}
                    elseif($null -eq $prep.Probe -or $null -eq $prep.Media){throw 'MP4 preparation returned no media model.'}
                    else {$script:Mp4Probe=$prep.Probe;$script:NativeInfo=$prep.Probe.Info;$script:ReadyMedia=$prep.Media;Complete-NativeMetadata}
                }
                finally {$prep.Dispose()}
            }
        }
        elseif($script:ScanJob) {
            $bar.Value=[Math]::Min(99,[Math]::Max(0,$script:ScanJob.Progress))
            $status.Text=('{0}% | {1:N0} video packets'-f$bar.Value,$script:ScanJob.Count)
            if($script:ScanJob.Done) {
                $j=$script:ScanJob;$script:ScanJob=$null
                if(-not $script:Cancelled -and $j.ExitCode -eq 0) {
                    if($script:NativeInfo.Container -eq 'MP4 / MOV') {
                        $c=$j
                    }
                    else {
                        if(-not $j.CanonicalAvailable -or $null -eq $j.CanonicalScanner){$detail=$j.CanonicalFailureDetail;if([string]::IsNullOrWhiteSpace($detail)){$detail='Canonical scanner returned no additional detail.'};throw ('Canonical codec analysis did not complete.'+[Environment]::NewLine+$detail)}
                        $c=$j.CanonicalScanner
                    }
                    if($null -eq $c -or $c.ExitCode -ne 0){$detail=if($c -and $c.Error){$c.Error}else{'No codec analysis detail was returned.'};throw ('Canonical codec analysis failed.'+[Environment]::NewLine+$detail)}
                    $script:Av1Diagnostic=[pscustomobject]@{ObuTotal=$c.Av1ObuTotal;Sequence=$c.Av1SequenceObu;TemporalDelimiter=$c.Av1TemporalDelimiterObu;FrameHeader=$c.Av1FrameHeaderObu;TileGroup=$c.Av1TileGroupObu;Metadata=$c.Av1MetadataObu;Frame=$c.Av1FrameObu;RedundantFrameHeader=$c.Av1RedundantFrameHeaderObu;TileList=$c.Av1TileListObu;Padding=$c.Av1PaddingObu;Unknown=$c.Av1UnknownObu;FrameBearing=$c.Av1FrameBearingObu;SamplesWithFrame=$c.Av1SamplesWithFrame;SamplesWithoutFrame=$c.Av1SamplesWithoutFrame;Rejected=$c.Av1ObuRejected;FirstError=$c.Av1FirstError;FrameHeaderParsed=$c.Av1FrameHeaderParsed;FrameHeaderRejected=$c.Av1FrameHeaderRejected;ShowExisting=$c.Av1ShowExisting;NewFrames=$c.Av1NewFrames;KeyFrames=$c.Av1KeyFrames;InterFrames=$c.Av1InterFrames;IntraOnlyFrames=$c.Av1IntraOnlyFrames;SwitchFrames=$c.Av1SwitchFrames;ShownFrames=$c.Av1ShownFrames;HiddenFrames=$c.Av1HiddenFrames;ShowableFrames=$c.Av1ShowableFrames;ErrorResilientFrames=$c.Av1ErrorResilientFrames;DisableCdfUpdateFrames=$c.Av1DisableCdfUpdateFrames;FrameHeaderFirstError=$c.Av1FrameHeaderFirstError;StateParsed=$c.Av1StateParsed;StateRejected=$c.Av1StateRejected;ScreenContentFrames=$c.Av1ScreenContentFrames;IntegerMvFrames=$c.Av1IntegerMvFrames;SizeOverrideFrames=$c.Av1SizeOverrideFrames;PrimaryRefNoneFrames=$c.Av1PrimaryRefNoneFrames;RefreshAllFrames=$c.Av1RefreshAllFrames;RefreshPartialFrames=$c.Av1RefreshPartialFrames;OrderHintSum=$c.Av1OrderHintSum;StateFirstError=$c.Av1StateFirstError;GeometryParsed=$c.Av1GeometryParsed;GeometryRejected=$c.Av1GeometryRejected;ShortRefSignalingFrames=$c.Av1ShortRefSignalingFrames;ExplicitRefFrames=$c.Av1ExplicitRefFrames;FoundRefSizeFrames=$c.Av1FoundRefSizeFrames;RenderOverrideFrames=$c.Av1RenderOverrideFrames;SuperresFrames=$c.Av1SuperresFrames;AllowIntrabcFrames=$c.Av1AllowIntrabcFrames;HighPrecisionMvFrames=$c.Av1HighPrecisionMvFrames;SwitchableFilterFrames=$c.Av1SwitchableFilterFrames;MotionModeSwitchableFrames=$c.Av1MotionModeSwitchableFrames;UseRefFrameMvsFrames=$c.Av1UseRefFrameMvsFrames;FrameWidthSum=$c.Av1FrameWidthSum;FrameHeightSum=$c.Av1FrameHeightSum;RenderWidthSum=$c.Av1RenderWidthSum;RenderHeightSum=$c.Av1RenderHeightSum;GeometryFirstError=$c.Av1GeometryFirstError;QuantParsed=$c.Av1QuantParsed;QuantRejected=$c.Av1QuantRejected;DisableFrameEndCdfFrames=$c.Av1DisableFrameEndCdfFrames;SingleTileFrames=$c.Av1SingleTileFrames;BaseQAverage=$c.Av1BaseQAverage;BaseQStdDev=$c.Av1BaseQStdDev;BaseQMinimum=$c.Av1BaseQMinimum;BaseQMaximum=$c.Av1BaseQMaximum;YDcDeltaNonZero=$c.Av1YDcDeltaNonZero;UDcDeltaNonZero=$c.Av1UDcDeltaNonZero;UAcDeltaNonZero=$c.Av1UAcDeltaNonZero;VDcDeltaNonZero=$c.Av1VDcDeltaNonZero;VAcDeltaNonZero=$c.Av1VAcDeltaNonZero;QMatrixFrames=$c.Av1QMatrixFrames;QuantFirstError=$c.Av1QuantFirstError;BaseQHistogram=$c.Av1BaseQHistogram}
                    $script:HevcDiagnostic=[pscustomobject]@{Vcl=$c.HevcVcl;Irap=$c.HevcIrap;Idr=$c.HevcIdr;Cra=$c.HevcCra;Bla=$c.HevcBla;Trail=$c.HevcTrail;Rasl=$c.HevcRasl;Radl=$c.HevcRadl;SliceParsed=$c.HevcSliceParsed;SliceRejected=$c.HevcSliceRejected;PrefixParsed=$c.HevcPrefixParsed;PrefixRejected=$c.HevcPrefixRejected;PrefixFirstError=$c.HevcPrefixFirstError;NativeTypeSequenceSha256=$c.HevcTypeSequenceHash}
                    $script:SliceQpDiagnostic=[pscustomobject]@{Parsed=$c.SliceHeaderOk;Failed=$c.SliceHeaderFailed;IOk=$c.SliceIOk;POk=$c.SlicePOk;BOk=$c.SliceBOk;IFail=$c.SliceIFail;PFail=$c.SlicePFail;BFail=$c.SliceBFail;Eof=$c.FailEof;Alignment=$c.FailAlignment;Qp=$c.FailQp;RefList=$c.FailRefList;Marking=$c.FailMarking;Other=$c.FailOther;FirstError=$c.FirstSliceError;Average=$c.SliceQpAverage;StdDev=$c.SliceQpStdDev;Minimum=$c.SliceQpMinimum;Maximum=$c.SliceQpMaximum;IAverage=$c.IQpAverage;PAverage=$c.PQpAverage;BAverage=$c.BQpAverage;IStdDev=$c.IQpStdDev;PStdDev=$c.PQpStdDev;BStdDev=$c.BQpStdDev;Histogram=$c.QpHistogram}
                    $script:NativeHevcQpDiagnostic=$script:SliceQpDiagnostic
                    $script:PacketEngine=if($script:NativeInfo.Container -eq 'MP4 / MOV'){'Canonical LSD media pipeline (Native MP4 sample tables)'}else{'Canonical LSD media pipeline'}
                    Finish-Scan $c.Result $c.Bins
                    Log ('LSD 2.0 pipeline: '+$script:NativeInfo.Container+' reader -> canonical sample index -> shared AVC/HEVC/AV1 analyzer.')
                }
                else { Log ('Native analysis failed. '+$j.Error) }
                $j.Dispose();$elapsed=([DateTime]::UtcNow-$script:StageStarted).TotalSeconds;$speed=if($elapsed -gt 0){(Get-Item -LiteralPath $script:File).Length/1MB/$elapsed}else{0};$pps=if($elapsed -gt 0){$script:PacketResult.Count/$elapsed}else{0};Log ('Fast native analysis: {0:N2} s | {1:N1} MiB/s | {2:N0} packets/s.' -f $elapsed,$speed,$pps);Busy $false;$status.Text=('Complete - canonical pipeline | {0:N1} MiB/s | {1:N0} packets/s' -f $speed,$pps)
            }
        }
    }
    catch {
        Log ('UI timer error: '+$_.Exception.Message)
        $status.Text='Error - see Log tab'
        if($script:Mp4PrepJob){$script:Mp4PrepJob.Cancel();$script:Mp4PrepJob.Dispose();$script:Mp4PrepJob=$null};if($script:ScanJob){$script:ScanJob.Cancel();$script:ScanJob.Dispose();$script:ScanJob=$null}
        Busy $false
        [Windows.Forms.MessageBox]::Show($_.Exception.Message,'LSD runtime error')|Out-Null
    }
})
$timer.Start()
$form.Add_SizeChanged({if($chart.IsHandleCreated){$chart.BeginInvoke([Action]{if(-not $chart.IsDisposed){$chart.Invalidate($true);$chart.Refresh()}})|Out-Null}})
$form.Add_ResizeEnd({if(-not $chart.IsDisposed){$chart.Invalidate($true);$chart.Refresh()}})
function Pick{$d=New-Object Windows.Forms.OpenFileDialog;$d.Filter='Video files|*.avi;*.mkv;*.mp4;*.m4v;*.mov;*.webm;*.ts;*.m2ts;*.mpg;*.mpeg;*.vob;*.wmv;*.flv;*.ogv;*.264;*.h264;*.265;*.h265;*.hevc|All files|*.*';if($d.ShowDialog() -eq 'OK'){Start-Meta $d.FileName};$d.Dispose()}
$open.Add_Click({Pick});$cancel.Add_Click({Cancel});$copy.Add_Click({if($summary.Text){[Windows.Forms.Clipboard]::SetText($summary.Text);$status.Text='Report copied'}})
$dragEnter={if($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)){$_.Effect='Copy'}else{$_.Effect='None'}};$dragDrop={$f=$_.Data.GetData([Windows.Forms.DataFormats]::FileDrop);if($f.Count){Start-Meta $f[0]}};$form.Add_DragEnter($dragEnter);$form.Add_DragDrop($dragDrop);$drop.Add_DragEnter($dragEnter);$drop.Add_DragDrop($dragDrop);$form.Add_KeyDown({if($_.KeyCode -eq 'Escape'){Cancel}elseif($_.Control-and$_.KeyCode -eq 'O'){Pick}});$form.Add_FormClosing({Cancel;$timer.Stop();if($script:Mp4PrepJob){$script:Mp4PrepJob.Dispose()};if($script:ScanJob){$script:ScanJob.Dispose()};[Threading.Thread]::CurrentThread.CurrentCulture=$script:OriginalCulture;[Threading.Thread]::CurrentThread.CurrentUICulture=$script:OriginalCulture});[void]$form.ShowDialog()