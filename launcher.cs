using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

// AC8 离线启动器 —— 安装器会把它放到游戏根目录，命名为 start_protected_game.exe
// 作用：接管 Steam 的默认启动目标，以离线方式拉起真正的游戏进程。
//   1) 设置 SteamAppId / SteamGameId，保证 Steamworks 正常初始化（成就、云存档）
//   2) 设置 EOS_USE_ANTICHEATCLIENTNULL=1，让 EOS 反作弊客户端为空实现（EAC 不加载）
//   3) 等待游戏退出后再退出，使 Steam 的游玩时长统计与覆盖层行为保持正常
internal static class Program
{
    private const string AppId = "2288340";

    [STAThread]
    private static int Main(string[] args)
    {
        string baseDir = AppDomain.CurrentDomain.BaseDirectory;
        string gameExe = Path.Combine(baseDir, @"Game\Binaries\Win64\AceCombat8.exe");

        if (!File.Exists(gameExe))
        {
            MessageBox.Show(
                "找不到游戏主程序：" + Environment.NewLine + gameExe + Environment.NewLine + Environment.NewLine +
                "请确认本文件位于游戏根目录（与 Game 文件夹同级）。",
                "AC8 离线启动器", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }

        try
        {
            ProcessStartInfo psi = new ProcessStartInfo(gameExe);
            psi.WorkingDirectory = Path.GetDirectoryName(gameExe);
            psi.UseShellExecute = false;
            psi.EnvironmentVariables["SteamAppId"] = AppId;
            psi.EnvironmentVariables["SteamGameId"] = AppId;
            psi.EnvironmentVariables["EOS_USE_ANTICHEATCLIENTNULL"] = "1";

            using (Process p = Process.Start(psi))
            {
                if (p == null) return 1;
                p.WaitForExit();          // 让 Steam 看到本进程活到游戏结束
                return p.ExitCode;
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show("启动失败：" + ex.Message, "AC8 离线启动器",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
