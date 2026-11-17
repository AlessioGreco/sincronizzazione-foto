// SincronizzaFoto single-file launcher.
// The whole app (scripts, UI, languages, guides) is embedded as "app.zip". On start it is unpacked once to
// %LOCALAPPDATA%\SincronizzaFoto\app-<id> and started with the Windows PowerShell that ships with Windows.
// Personal data (config.json, history.json) lives in %APPDATA%\SincronizzaFoto, so updating the exe keeps it.
using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Cryptography;
using System.Windows.Forms;

static class Launcher
{
    [STAThread]
    static int Main()
    {
        try
        {
            string local = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SincronizzaFoto");
            string data = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "SincronizzaFoto");

            byte[] zip;
            using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream("app.zip"))
            using (MemoryStream ms = new MemoryStream())
            {
                s.CopyTo(ms);
                zip = ms.ToArray();
            }

            string id;
            using (SHA256 sha = SHA256.Create())
                id = BitConverter.ToString(sha.ComputeHash(zip), 0, 6).Replace("-", "").ToLowerInvariant();

            string appDir = Path.Combine(local, "app-" + id);
            string script = Path.Combine(appDir, "SincronizzaFoto.ps1");
            if (!File.Exists(script))
            {
                string tmp = appDir + ".tmp" + Process.GetCurrentProcess().Id;
                if (Directory.Exists(tmp)) Directory.Delete(tmp, true);
                Directory.CreateDirectory(tmp);
                using (ZipArchive za = new ZipArchive(new MemoryStream(zip), ZipArchiveMode.Read))
                    foreach (ZipArchiveEntry e in za.Entries)
                    {
                        if (e.FullName.EndsWith("/")) continue;
                        string dest = Path.Combine(tmp, e.FullName.Replace('/', Path.DirectorySeparatorChar));
                        Directory.CreateDirectory(Path.GetDirectoryName(dest));
                        e.ExtractToFile(dest, true);
                    }
                try { Directory.Move(tmp, appDir); }
                catch { if (!File.Exists(script)) throw; } // another instance won the race
                try { if (Directory.Exists(tmp)) Directory.Delete(tmp, true); } catch { }
                // drop folders left by older versions
                try
                {
                    foreach (string d in Directory.GetDirectories(local, "app-*"))
                        if (!string.Equals(d, appDir, StringComparison.OrdinalIgnoreCase))
                            try { Directory.Delete(d, true); } catch { }
                }
                catch { }
            }

            string ps = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");
            ProcessStartInfo psi = new ProcessStartInfo(ps,
                "-NoProfile -ExecutionPolicy Bypass -Sta -WindowStyle Hidden -File \"" + script + "\"");
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.WorkingDirectory = appDir;
            psi.EnvironmentVariables["SINCRONIZZAFOTO_DATA"] = data;
            Process.Start(psi);
            return 0;
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "SincronizzaFoto", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
