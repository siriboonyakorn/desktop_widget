using System;
using System.Runtime.InteropServices;
public static class MenuAudio {
 [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class Enumerator {}
 [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IEnum {
  int EnumAudioEndpoints(int flow,int state,out IntPtr devices);
  [PreserveSig] int GetDefaultAudioEndpoint(int flow,int role,out IDevice device);
 }
 [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IDevice {
  [PreserveSig] int Activate(ref Guid iid,int context,IntPtr parameters,[MarshalAs(UnmanagedType.IUnknown)] out object value);
 }
 [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IVolume {
  [PreserveSig] int RegisterControlChangeNotify(IntPtr p); [PreserveSig] int UnregisterControlChangeNotify(IntPtr p); [PreserveSig] int GetChannelCount(out uint count);
  [PreserveSig] int SetMasterVolumeLevel(float v,ref Guid g); [PreserveSig] int SetMasterVolumeLevelScalar(float v,ref Guid g);
  [PreserveSig] int GetMasterVolumeLevel(out float v); [PreserveSig] int GetMasterVolumeLevelScalar(out float v);
  [PreserveSig] int SetChannelVolumeLevel(uint c,float v,ref Guid g); [PreserveSig] int SetChannelVolumeLevelScalar(uint c,float v,ref Guid g);
  [PreserveSig] int GetChannelVolumeLevel(uint c,out float v); [PreserveSig] int GetChannelVolumeLevelScalar(uint c,out float v);
  [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute,ref Guid g); [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
 }
 static T Use<T>(Func<IVolume,T> fn) {
  IEnum e=null; IDevice d=null; object obj=null;
  try { e=(IEnum)new Enumerator(); Marshal.ThrowExceptionForHR(e.GetDefaultAudioEndpoint(0,1,out d)); var iid=typeof(IVolume).GUID; Marshal.ThrowExceptionForHR(d.Activate(ref iid,23,IntPtr.Zero,out obj)); return fn((IVolume)obj); }
  finally { if(obj!=null)Marshal.ReleaseComObject(obj); if(d!=null)Marshal.ReleaseComObject(d); if(e!=null)Marshal.ReleaseComObject(e); }
 }
 public static float Volume() {return Use(v=>{float x;Marshal.ThrowExceptionForHR(v.GetMasterVolumeLevelScalar(out x));return x;});}
 public static bool Muted() {return Use(v=>{bool x;Marshal.ThrowExceptionForHR(v.GetMute(out x));return x;});}
 public static void SetVolume(float x) {Use(v=>{var g=Guid.Empty;Marshal.ThrowExceptionForHR(v.SetMasterVolumeLevelScalar(Math.Max(0,Math.Min(1,x)),ref g));return 0;});}
 public static void SetMuted(bool x) {Use(v=>{var g=Guid.Empty;Marshal.ThrowExceptionForHR(v.SetMute(x,ref g));return 0;});}
}
public static class MenuWifi {
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct Interface { public Guid Id; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=256)] public string Description; public int State; }
 [StructLayout(LayoutKind.Sequential)] struct Ssid { public uint Length; [MarshalAs(UnmanagedType.ByValArray,SizeConst=32)] public byte[] Bytes; }
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct Network {
  [MarshalAs(UnmanagedType.ByValTStr,SizeConst=256)] public string Profile; public Ssid Ssid; public int Bss; public uint BssCount;
  [MarshalAs(UnmanagedType.Bool)] public bool Connectable; public uint Reason; public uint PhyCount;
  [MarshalAs(UnmanagedType.ByValArray,SizeConst=8)] public int[] Phy; [MarshalAs(UnmanagedType.Bool)] public bool MorePhy;
  public uint Signal; [MarshalAs(UnmanagedType.Bool)] public bool Security; public int Auth,Cipher; public uint Flags,Reserved;
 }
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct Connection { public int Mode; [MarshalAs(UnmanagedType.LPWStr)] public string Profile; public IntPtr Ssid,Desired; public int Bss; public uint Flags; }
 public class Item { public string Name,Profile,SsidHex; public int Auth,Cipher; public Guid Adapter; public uint Signal; public bool Connected,Secure; }
 [DllImport("wlanapi.dll")] static extern uint WlanOpenHandle(uint version,IntPtr reserved,out uint negotiated,out IntPtr handle);
 [DllImport("wlanapi.dll")] static extern uint WlanCloseHandle(IntPtr h,IntPtr r);
 [DllImport("wlanapi.dll")] static extern uint WlanEnumInterfaces(IntPtr h,IntPtr r,out IntPtr list);
 [DllImport("wlanapi.dll")] static extern uint WlanGetAvailableNetworkList(IntPtr h,ref Guid id,uint flags,IntPtr r,out IntPtr list);
 [DllImport("wlanapi.dll")] static extern void WlanFreeMemory(IntPtr p);
 [DllImport("wlanapi.dll",CharSet=CharSet.Unicode)] static extern uint WlanConnect(IntPtr h,ref Guid id,ref Connection c,IntPtr r);
 static void Check(uint x) {if(x!=0)throw new System.ComponentModel.Win32Exception((int)x);}
 public static Item[] Networks() {
  IntPtr h=IntPtr.Zero,list=IntPtr.Zero; uint ver; var items=new System.Collections.Generic.List<Item>();
  try {Check(WlanOpenHandle(2,IntPtr.Zero,out ver,out h));Check(WlanEnumInterfaces(h,IntPtr.Zero,out list));
   for(int i=0;i<Marshal.ReadInt32(list);i++) {
    var adapter=(Interface)Marshal.PtrToStructure(IntPtr.Add(list,8+i*Marshal.SizeOf(typeof(Interface))),typeof(Interface)); IntPtr nets=IntPtr.Zero;
    try {Check(WlanGetAvailableNetworkList(h,ref adapter.Id,0,IntPtr.Zero,out nets));
     for(int n=0;n<Marshal.ReadInt32(nets);n++) {var v=(Network)Marshal.PtrToStructure(IntPtr.Add(nets,8+n*Marshal.SizeOf(typeof(Network))),typeof(Network));
      string name=System.Text.Encoding.UTF8.GetString(v.Ssid.Bytes,0,(int)Math.Min(v.Ssid.Length,32));
      if(name.Length>0)items.Add(new Item{Name=name,Profile=v.Profile,Adapter=adapter.Id,Signal=v.Signal,Connected=(v.Flags&1)!=0,Secure=v.Security,Auth=v.Auth,Cipher=v.Cipher,SsidHex=BitConverter.ToString(v.Ssid.Bytes,0,(int)Math.Min(v.Ssid.Length,32)).Replace("-","")});
     }
    } finally {if(nets!=IntPtr.Zero)WlanFreeMemory(nets);}
   }return items.ToArray();
  } finally {if(list!=IntPtr.Zero)WlanFreeMemory(list);if(h!=IntPtr.Zero)WlanCloseHandle(h,IntPtr.Zero);}
 }
 public static string ProfileXml(Item item,string password) {
  string auth,cipher;
  if(!item.Secure) {auth="open";cipher="none";}
  else if(item.Auth==7 && item.Cipher==4) {auth="WPA2PSK";cipher="AES";}
  else if(item.Auth==9 && item.Cipher==4) {auth="WPA3SAE";cipher="AES";}
  else throw new NotSupportedException("This network uses enterprise or legacy security. Set it up in Windows first.");
  if(item.Secure && (password==null || password.Length<8 || password.Length>63)) throw new ArgumentException("Enter a password between 8 and 63 characters.");
  Func<string,string> escape=System.Security.SecurityElement.Escape;
  string key=item.Secure ? "<sharedKey><keyType>passPhrase</keyType><protected>false</protected><keyMaterial>"+escape(password)+"</keyMaterial></sharedKey>" : "";
  return "<WLANProfile xmlns=\"http://www.microsoft.com/networking/WLAN/profile/v1\"><name>"+escape(item.Name)+"</name><SSIDConfig><SSID><hex>"+item.SsidHex+"</hex></SSID></SSIDConfig><connectionType>ESS</connectionType><connectionMode>manual</connectionMode><MSM><security><authEncryption><authentication>"+auth+"</authentication><encryption>"+cipher+"</encryption><useOneX>false</useOneX></authEncryption>"+key+"</security></MSM></WLANProfile>";
 }
 public static System.Threading.Tasks.Task<bool> ConnectAsync(Item item,string password) {
  return System.Threading.Tasks.Task.Run(() => {
   Connect(item,password);
   for(int i=0;i<25;i++) {
    System.Threading.Thread.Sleep(1000);
    foreach(var network in Networks()) if(network.Adapter==item.Adapter && network.SsidHex==item.SsidHex && network.Connected)return true;
   }
   return false;
  });
 }
 public static void Connect(Item item) { Connect(item,null); }
 public static void Connect(Item item,string password) {
  bool saved=!String.IsNullOrEmpty(item.Profile);
  string profile=saved ? item.Profile : ProfileXml(item,password);
  IntPtr h;uint v;Check(WlanOpenHandle(2,IntPtr.Zero,out v,out h));
  try {var c=new Connection{Mode=saved?0:1,Profile=profile,Bss=1};var id=item.Adapter;Check(WlanConnect(h,ref id,ref c,IntPtr.Zero));} finally {WlanCloseHandle(h,IntPtr.Zero);}
 }

}
public static class MenuGlass {
 [StructLayout(LayoutKind.Sequential)] struct Accent {public int State,Flags;public uint Color;public int Animation;}
 [StructLayout(LayoutKind.Sequential)] struct Data {public int Attribute;public IntPtr Pointer;public int Size;}
 [StructLayout(LayoutKind.Sequential)] struct Rect {public int Left,Top,Right,Bottom;}
 [DllImport("user32.dll")] static extern int SetWindowCompositionAttribute(IntPtr h,ref Data data);
 [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h,int index);
 [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h,out Rect r);
 [DllImport("gdi32.dll")] static extern IntPtr CreateRoundRectRgn(int l,int t,int r,int b,int w,int h);
 [DllImport("user32.dll")] static extern int SetWindowRgn(IntPtr h,IntPtr region,bool redraw);
 [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr h);
 public static bool Apply(IntPtr h,int radius) {
  if(h==IntPtr.Zero)return false;
  IntPtr p=IntPtr.Zero;
  try {
   // WPF transparent popups are layered windows. Accent acrylic paints a rectangular
   // compositor surface beyond their alpha mask, even after SetWindowRgn succeeds.
   // Disable that layer and let WPF draw the complete rounded material instead.
   if((GetWindowLong(h,-20)&0x80000)!=0) {
    var off=new Accent();p=Marshal.AllocHGlobal(Marshal.SizeOf(off));Marshal.StructureToPtr(off,p,false);
    var clear=new Data{Attribute=19,Pointer=p,Size=Marshal.SizeOf(off)};
    SetWindowCompositionAttribute(h,ref clear);return false;
   }
   using(var key=Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize")) {
    if(key!=null && Convert.ToInt32(key.GetValue("EnableTransparency",1))==0)return false;
   }
   // Acrylic is optional on layered popup HWNDs. An opaque material is used if unavailable.
   var a=new Accent{State=4,Flags=2,Color=0xDA302820};
   p=Marshal.AllocHGlobal(Marshal.SizeOf(a));Marshal.StructureToPtr(a,p,false);
   var d=new Data{Attribute=19,Pointer=p,Size=Marshal.SizeOf(a)};
   if(SetWindowCompositionAttribute(h,ref d)==0)return false;
   Round(h,radius);return true;
  } catch {return false;} finally {if(p!=IntPtr.Zero)Marshal.FreeHGlobal(p);}
 }
 public static void Round(IntPtr h,int radius) {
  Rect r;if(!GetClientRect(h,out r))return;
  var region=CreateRoundRectRgn(0,0,r.Right+1,r.Bottom+1,radius*2,radius*2);
  if(SetWindowRgn(h,region,true)==0)DeleteObject(region);
 }
}
