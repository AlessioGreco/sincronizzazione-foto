# shellstream.ps1 - copy a file from the phone by reading its bytes ourselves.
#
# Shell.Application.CopyHere hands the copy to Windows, which pops up its own progress window for
# anything that takes more than a few seconds (videos) and ignores the "no UI" flags. Here the file
# is opened as an IStream (BHID_Stream) and written to disk in 1 MB blocks: no Windows dialog,
# byte-level progress, and cancel works in the middle of a big file.
#
# How the stream is obtained: the FolderItem we already have exposes IPersistFolder2, whose
# GetCurFolder returns the item's PIDL (its internal identifier). SHCreateItemFromIDList turns it
# into an IShellItem and BindToHandler(BHID_Stream) gives the IStream. (Parsing the item's path
# text does not work for phones: "\\?\usb#..." is rejected with E_INVALIDARG.)

if (-not ('SF.ShellStream' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

namespace SF {
    [ComImport, Guid("43826d1e-e718-42ee-bc55-a1e261c37bfe"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IShellItem {
        [PreserveSig] int BindToHandler(IntPtr pbc, [In] ref Guid bhid, [In] ref Guid riid, out IntPtr ppv);
        [PreserveSig] int GetParent(out IShellItem ppsi);
        [PreserveSig] int GetDisplayName(uint sigdnName, out IntPtr ppszName);
        [PreserveSig] int GetAttributes(uint sfgaoMask, out uint psfgaoAttribs);
        [PreserveSig] int Compare(IShellItem psi, uint hint, out int piOrder);
    }

    [ComImport, Guid("1AC3D9F0-175C-11d1-95BE-00609797EA4F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPersistFolder2 {
        [PreserveSig] int GetClassID(out Guid pClassID);                 // IPersist
        [PreserveSig] int Initialize(IntPtr pidl);                       // IPersistFolder
        [PreserveSig] int GetCurFolder(out IntPtr ppidl);                // IPersistFolder2
    }

    public static class ShellStream {
        [DllImport("shell32.dll", PreserveSig = false)]
        static extern void SHCreateItemFromIDList(IntPtr pidl, [In] ref Guid riid,
            [MarshalAs(UnmanagedType.Interface)] out IShellItem item);

        static Guid BHID_Stream    = new Guid("1CEBB3AB-7C10-499A-A417-92CA16C4CB83");
        static Guid IID_IStream    = new Guid("0000000c-0000-0000-C000-000000000046");
        static Guid IID_IShellItem = new Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE");
        static Guid IID_IPersistFolder2 = new Guid("1AC3D9F0-175C-11d1-95BE-00609797EA4F");

        // Opens the file behind a Shell FolderItem (COM object) as an IStream.
        static IStream OpenStream(object folderItem, out IShellItem item) {
            IntPtr unk = Marshal.GetIUnknownForObject(folderItem);
            IntPtr pf; Guid g = IID_IPersistFolder2;
            int hr = Marshal.QueryInterface(unk, ref g, out pf);
            Marshal.Release(unk);
            if (hr != 0) throw new COMException("The item has no PIDL accessor", hr);
            IntPtr pidl = IntPtr.Zero;
            try {
                IPersistFolder2 persist = (IPersistFolder2)Marshal.GetObjectForIUnknown(pf);
                hr = persist.GetCurFolder(out pidl);
                if (hr != 0 || pidl == IntPtr.Zero) throw new COMException("Cannot read the item identifier", hr);
                Guid iid = IID_IShellItem;
                SHCreateItemFromIDList(pidl, ref iid, out item);
            } finally {
                Marshal.Release(pf);
                if (pidl != IntPtr.Zero) Marshal.FreeCoTaskMem(pidl);
            }
            IntPtr ppv; Guid bh = BHID_Stream; Guid ri = IID_IStream;
            hr = item.BindToHandler(IntPtr.Zero, ref bh, ref ri, out ppv);
            if (hr != 0) throw new COMException("Cannot open the file as a stream", hr);
            IStream stream = (IStream)Marshal.GetObjectForIUnknown(ppv);
            Marshal.Release(ppv);
            return stream;
        }

        // Copies the item to destPath. Returns the bytes written.
        // progress(bytesSoFar) is called after each block; cancelled() is polled before each block.
        public static long CopyToFile(object folderItem, string destPath, Action<long> progress, Func<bool> cancelled) {
            IShellItem item;
            IStream stream = OpenStream(folderItem, out item);
            long total = 0;
            IntPtr pRead = Marshal.AllocCoTaskMem(4);
            try {
                using (FileStream fs = new FileStream(destPath, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20)) {
                    byte[] buf = new byte[1 << 20];
                    while (true) {
                        if (cancelled != null && cancelled()) throw new OperationCanceledException();
                        stream.Read(buf, buf.Length, pRead);
                        int n = Marshal.ReadInt32(pRead);
                        if (n <= 0) break;
                        fs.Write(buf, 0, n);
                        total += n;
                        if (progress != null) progress(total);
                    }
                }
            } finally {
                Marshal.FreeCoTaskMem(pRead);
                Marshal.ReleaseComObject(stream);
                Marshal.ReleaseComObject(item);
            }
            return total;
        }
    }
}
'@
}
