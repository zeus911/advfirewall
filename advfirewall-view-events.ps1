if ($PSVersionTable.PSVersion.Major -lt 3) {
    [string] $PSScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
}
if (Test-Path -Path $PSScriptRoot\advfirewall-events.csv) {
    if ($PSVersionTable.PSVersion.Major -lt 3) {
        $WaitHelperSource = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

namespace Utils
{
  public delegate bool Win32Callback(IntPtr hwnd, IntPtr lParam);

  public class WindowHelper
  {
    private const int PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
    private IntPtr _mainHwnd;
    private IntPtr _ogvHwnd;
    private IntPtr _poshProcessHandle;
    private int _poshPid;
    private bool _ogvWindowFound;

    public WindowHelper()
    {
      Process process = Process.GetCurrentProcess();
      _mainHwnd = process.MainWindowHandle;
      _poshProcessHandle = process.Handle;
      _poshPid = process.Id;
    }

    public void WaitForOutGridViewWindowToClose()
    {
      do
      {
        _ogvWindowFound = false;
        EnumChildWindows(IntPtr.Zero, EnumChildWindowsHandler,
                 IntPtr.Zero);
        Thread.Sleep(500);
      } while (_ogvWindowFound);
    }

    [DllImport("User32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool EnumChildWindows(
      IntPtr parentHandle, Win32Callback callback, IntPtr lParam);

    [DllImport("User32.dll")]
    public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int processId);

    [DllImport("Kernel32.dll")]
    public static extern int GetLastError();

    private bool EnumChildWindowsHandler(IntPtr hwnd, IntPtr lParam)
    {
      if (_ogvHwnd == IntPtr.Zero)
      {
        int processId;
        int thread = GetWindowThreadProcessId(hwnd, out processId);

        if (processId == 0)
        {
          Console.WriteLine("GetWindowThreadProcessId error:{0}",
                   GetLastError());
          return true;
        }
        if (processId == _poshPid)
        {
          if (hwnd != _mainHwnd)
          {
            _ogvHwnd = hwnd;
            _ogvWindowFound = true;
            return false;
          }
        }
      }
      else if (hwnd == _ogvHwnd)
      {
        _ogvWindowFound = true;
        return false;
      }
      return true;
    }
  }
}
'@
        Add-Type -TypeDefinition $WaitHelperSource
        Import-Csv -Path $PSScriptRoot\advfirewall-events.csv | Sort-Object -Property SystemTime -Descending | Out-GridView -Title "Windows Firewall Ereignisprotokoll"
        $WaitHelper = New-Object -TypeName Utils.WindowHelper
        $WaitHelper.WaitForOutGridViewWindowToClose()
    } else {
        Import-Csv -Path $PSScriptRoot\advfirewall-events.csv | Sort-Object -Property SystemTime -Descending | Out-GridView -Title "Windows Firewall Ereignisprotokoll" -Wait
    }
} else {
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    $Result = [System.Windows.Forms.MessageBox]::Show(
        "Es ist keine Log Datei vorhanden!",
        "Windows Firewall", 0, [System.Windows.Forms.MessageBoxIcon]::Error
    )
}