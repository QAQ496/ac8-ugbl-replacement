using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows.Forms;
using Microsoft.Win32;

namespace Ac8UgbL
{
    public class InstallerForm : Form
    {
        private const string AppId = "2288340";
        private const string ModName = "AC8MissileBomb";
        private const string Marker = "AC8-UGBL-mod.marker";
        private const string StateFile = "AC8-UGBL-state.txt";
        private const string FeaturesBackupSuffix = ".ac8ugbl.bak";
        private const string ProtectedExe = "start_protected_game.exe";
        private const string ProtectedBackupSuffix = ".ac8ugbl.bak";

        private Label status;
        private string baseDir;
        private string win64;

        private static bool En = true;   // default UI language: English
        private Button bLang;
        private static string L(string zh, string en) { return En ? en : zh; }

        private void BuildUi()
        {
            SuspendLayout();
            Controls.Clear();
            baseDir = Path.GetDirectoryName(Application.ExecutablePath);
            win64 = FindWin64(baseDir);

            Text = L("AC8 UGBL 替换 Mod 安装器", "AC8 UGBL Replacement Mod Installer");
            ClientSize = new Size(640, 500);
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            Font = new Font("Microsoft YaHei UI", 9f);

            Label title = new Label();
            title.Text = L("皇牌空战8  UGBL 替换 Mod", "Ace Combat 8  -  UGBL Replacement Mod");
            title.Font = new Font("Microsoft YaHei UI", 13f, FontStyle.Bold);
            title.SetBounds(18, 12, 600, 30);
            Controls.Add(title);

            Button bEnhanced = MakeButton(L("安装 强化版", "Install  Enhanced"), 18, 52, 190);
            bEnhanced.Click += delegate { Install("enhanced"); };
            Controls.Add(bEnhanced);

            Button bNormal = MakeButton(L("安装 普通版", "Install  Standard"), 222, 52, 190);
            bNormal.Click += delegate { Install("normal"); };
            Controls.Add(bNormal);

            Button bRestore = MakeButton(L("还原游戏", "Restore game"), 426, 52, 190);
            bRestore.Click += delegate { Restore(); };
            Controls.Add(bRestore);

            Label head = new Label();
            head.Text = L("改动说明", "What this mod changes");
            head.Font = new Font("Microsoft YaHei UI", 10f, FontStyle.Bold);
            head.SetBounds(18, 98, 200, 22);
            Controls.Add(head);

            TextBox desc = new TextBox();
            desc.Multiline = true;
            desc.ReadOnly = true;
            desc.ScrollBars = ScrollBars.Vertical;
            desc.WordWrap = true;
            desc.BackColor = Color.White;
            desc.SetBounds(18, 122, 598, 318);
            desc.Text = Description();
            Controls.Add(desc);

            status = new Label();
            status.SetBounds(18, 448, 598, 44);
            status.ForeColor = Color.DimGray;
            Controls.Add(status);

            if (win64 == null)
                SetStatus(L("未找到游戏：本文件夹需要放在游戏根目录（含 Game 文件夹的那一层）。", "Game not found: this folder must sit in the game root directory (the folder that contains the Game folder).")
                        + L("现在可以预览界面，点击按钮不会有任何改动。", " The interface can be previewed now; clicking the buttons will not change anything."), true);
            else
                SetStatus(L("已找到游戏目录。安装后直接在 Steam 点「开始游戏」，不需要改任何 Steam 设置。", "Game folder found. After installing, just press Play in Steam; no Steam settings need changing."), false);
            bLang = new Button();
            bLang.Text = En ? "中文" : "English";
            bLang.SetBounds(516, 10, 106, 26);
            bLang.Click += delegate { En = !En; BuildUi(); };
            Controls.Add(bLang);
            bLang.BringToFront();
            ResumeLayout();
        }

        public InstallerForm()
        {
            baseDir = Path.GetDirectoryName(Application.ExecutablePath);
            win64 = FindWin64(baseDir);
            BuildUi();
        }

        public string LastStatus { get { return status.Text; } }
        public bool SuppressDialogs = false;
        public void DoInstall(string variant) { Install(variant); }
        public void DoRestore() { Restore(); }

        public string PublicNotice()
        {
            if (win64 == null) return null;
            return BuildNotice(DetectMode());
        }

        private Button MakeButton(string text, int x, int y, int w)
        {
            Button b = new Button();
            b.Text = text;
            b.SetBounds(x, y, w, 34);
            return b;
        }

        private static string Description()
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine(L("【强化版】", "[Enhanced version]"));
            sb.AppendLine(L("  · 标准导弹（MSL）外观替换为 UGBL 制导炸弹", "  - Standard missile (MSL) model replaced with the UGBL guided bomb"));
            sb.AppendLine(L("  · 伤害 40 → 90，爆炸范围 0 → 182 米", "  - Damage 40 -> 90, blast radius 0 -> 182 m"));
            sb.AppendLine(L("  · 在以上基础上，再叠加完整的导弹性能强化：", "  - On top of the above, the full missile performance enhancement is applied:"));
            sb.AppendLine(L("      飞行速度 1083 → 1458 米/秒，加速度同步提高", "      Speed 1083 -> 1458 m/s, acceleration raised as well"));
            sb.AppendLine(L("      导引方式改为比例导引并加入提前量预测，追踪更紧", "      Proportional navigation with lead prediction for tighter tracking"));
            sb.AppendLine(L("      锁定角 32.5° → 160°，最大转向角 40° → 150°", "      Lock cone 32.5 deg -> 160 deg, max turn angle 40 deg -> 150 deg"));
            sb.AppendLine(L("      锁定距离 2000 → 2400 米，锁定加速时间 1.0 → 2.75 秒", "      Lock range 2000 -> 2400 m, lock acceleration time 1.0 -> 2.75 s"));
            sb.AppendLine(L("      启用近炸引信，爆炸半径 50 米，溅射伤害 30", "      Proximity fuze enabled, blast radius 50 m, splash damage 30"));
            sb.AppendLine(L("      飞行寿命 9 → 15 秒，脱锁后自毁，云层内锁定衰减", "      Lifetime 9 -> 15 s, self-destruct after lock loss, lock decay inside clouds"));
            sb.AppendLine();
            sb.AppendLine(L("【普通版】", "[Standard version]"));
            sb.AppendLine(L("  · 只做三件事：替换外观、伤害 40 → 90、爆炸范围 0 → 182 米", "  - Only three changes: model swap, damage 40 -> 90, blast radius 0 -> 182 m"));
            sb.AppendLine(L("  · 速度、导引方式、锁定角与距离、近炸、寿命等全部保持游戏原版", "  - Speed, guidance, lock cone and range, proximity fuze and lifetime stay vanilla"));
            sb.AppendLine();
            sb.AppendLine(L("【安装方式（全自动识别，不改动 Steam 设置）】", "[Installation (fully automatic, no Steam setting changes)]"));
            sb.AppendLine(L("  · 干净的游戏：安装 Mod 运行库，并接管游戏的启动程序", "  - Clean game: installs the mod runtime and takes over the game launcher"));
            sb.AppendLine(L("  · 已有其他 Mod 运行库：只放本 Mod 文件，同样接管启动程序", "  - Existing mod runtime: only this mod's files are added, the launcher is taken over the same way"));
            sb.AppendLine(L("  · 已装鼠标飞控整合包：装成它的附加 Mod，共用它的启动方式，", "  - Mouse-flight integrated package detected: installs as its add-on mod, sharing its launch method,"));
            sb.AppendLine(L("    并把它自带的导弹增强切到「仅鼠标飞控」，避免改同一批数据", "    and its built-in missile enhancement is switched to \"mouse flight only\" to avoid editing the same data"));
            sb.AppendLine(L("  · 接管方式：把游戏根目录的 start_protected_game.exe 换成离线启动器，", "  - Takeover: replaces start_protected_game.exe in the game root with an offline launcher,"));
            sb.AppendLine(L("    原文件保留为备份，还原时原样放回；Steam 启动项保持原样", "    the original file is kept as a backup and restored exactly later; Steam launch options stay unchanged"));
            sb.AppendLine(L("  · 还原会按安装时记录的方式逐项恢复原状", "  - Restore reverts each item according to what was recorded during installation"));
            sb.AppendLine();
            sb.AppendLine(L("  · 仅限离线单人，不要带入线上或多人模式", "  - Offline single-player only; do not use in online or multiplayer modes"));
            return sb.ToString();
        }

        // ---------------- 环境探测 ----------------
        private enum Mode { Standalone, ExistingLoader, IntegratedPackage }

        private static string FindWin64(string start)
        {
            string cur = start;
            for (int i = 0; i < 5 && cur != null; i++)
            {
                string candidate = Path.Combine(cur, @"Game\Binaries\Win64");
                if (File.Exists(Path.Combine(candidate, "AceCombat8.exe"))) return candidate;
                cur = Path.GetDirectoryName(cur.TrimEnd('\\'));
            }
            return null;
        }

        private void SetStatus(string text, bool error)
        {
            status.Text = text;
            status.ForeColor = error ? Color.Firebrick : Color.DimGray;
        }

        // 游戏（或我们的启动器）正在运行时不替换文件
        private static bool GameRunning()
        {
            return Process.GetProcessesByName("AceCombat8").Length > 0
                || Process.GetProcessesByName("start_protected_game").Length > 0;
        }

        // 只有识别整合包时才读 Steam 配置，且只读不写
        private string IntegratedPackageDir()
        {
            try
            {
                string cur = CurrentLaunchOption();
                if (string.IsNullOrEmpty(cur)) return null;
                Match m = Regex.Match(cur, "\"([^\"]*Start-AC8-From-Steam\\.cmd)\"");
                if (!m.Success) return null;
                string file = m.Groups[1].Value;
                if (File.Exists(file)) return Path.GetDirectoryName(file);
            }
            catch { }
            return null;
        }

        private Mode DetectMode()
        {
            if (IntegratedPackageDir() != null) return Mode.IntegratedPackage;
            if (Directory.Exists(Path.Combine(win64, "ue4ss"))) return Mode.ExistingLoader;
            return Mode.Standalone;
        }

        private string BuildNotice(Mode mode)
        {
            StringBuilder sb = new StringBuilder();
            if (mode == Mode.IntegratedPackage)
            {
                string pkg = IntegratedPackageDir();
                sb.AppendLine(L("· 检测到鼠标飞控整合包：", "- Mouse-flight integrated package detected:") + pkg);
                sb.AppendLine(L("  将以「附加 Mod」方式安装：只往它的 ue4ss-mods 目录放文件，", "  Will be installed as an add-on mod: files only go into its ue4ss-mods folder,"));
                sb.AppendLine(L("  不安装运行库、不替换启动程序，继续用它原来的入口启动。", "  no runtime is installed and the launcher is not replaced; it keeps its own entry point."));
                if (MissileModeOn(pkg))
                {
                    sb.AppendLine(L("  它的导弹增强当前是开启状态，与本 Mod 改同一批数据。", "  Its missile enhancement is currently enabled and edits the same data as this mod."));
                    sb.AppendLine(L("  安装时会把它切换为「仅鼠标飞控」，点还原时自动切回。", "  It will be switched to \"mouse flight only\" during installation, and switched back when you restore."));
                }
                return sb.ToString().TrimEnd();
            }
            sb.AppendLine(L("· 不改动 Steam 的任何设置（启动项保持原样）。", "- Does not change any Steam settings (launch options stay as they are)."));
            if (mode == Mode.ExistingLoader)
            {
                sb.AppendLine(L("· 游戏目录里已有 Mod 运行库（UE4SS，可能来自其他 Mod）。", "- A mod runtime (UE4SS) already exists in the game folder, possibly from another mod."));
                sb.AppendLine(L("  本次只放本 Mod 的文件，不覆盖对方的 Mod。", "  Only this mod's files are added; the other mod is not overwritten."));
            }
            else
            {
                sb.AppendLine(L("· 未检测到其他 Mod 环境，将一并安装 Mod 运行库。", "- No other mod environment found; the mod runtime will be installed as well."));
            }
            sb.AppendLine(L("· 会接管游戏启动：把游戏根目录的 ", "- Will take over game start: replaces ") + ProtectedExe + L(" 换成离线启动器，", " with an offline launcher,"));
            sb.AppendLine(L("  原文件保留为备份，点「还原游戏」时原样放回。", "  the original file is kept as a backup and put back exactly when you press Restore."));
            sb.AppendLine(L("  之后在 Steam 点「开始游戏」即可，无需其它操作。", "  After that just press Play in Steam; no other steps needed."));
            return sb.ToString().TrimEnd();
        }

        private static bool MissileModeOn(string pkg)
        {
            try
            {
                string f = Path.Combine(pkg, "features.ini");
                if (!File.Exists(f)) return false;
                Match m = Regex.Match(File.ReadAllText(f, Encoding.UTF8), "missile_mode\\s*=\\s*(\\w+)");
                return m.Success && m.Groups[1].Value.ToLower() != "none";
            }
            catch { return false; }
        }

        // ---------------- payload 定位 ----------------
        private string[] PayloadRoots()
        {
            var roots = new System.Collections.Generic.List<string>();
            roots.Add(baseDir);
            roots.Add(Path.Combine(baseDir, "AC8-UGBL-Replacement"));
            string parent = Path.GetDirectoryName(baseDir.TrimEnd('\\'));
            if (!string.IsNullOrEmpty(parent)) roots.Add(parent);
            if (win64 != null)
            {
                try { roots.Add(Path.GetFullPath(Path.Combine(win64, @"..\..\.."))); }
                catch { }
            }
            return roots.ToArray();
        }

        private string FindPayloadDir(string relative)
        {
            foreach (string r in PayloadRoots())
            {
                if (string.IsNullOrEmpty(r)) continue;
                try
                {
                    string candidate = Path.Combine(r, relative);
                    if (Directory.Exists(candidate)) return candidate;
                }
                catch { }
            }
            return null;
        }

        private string FindPayloadFile(string relative)
        {
            foreach (string r in PayloadRoots())
            {
                if (string.IsNullOrEmpty(r)) continue;
                try
                {
                    string candidate = Path.Combine(r, relative);
                    if (File.Exists(candidate)) return candidate;
                }
                catch { }
            }
            return null;
        }

        // ---------------- 安装 / 还原 ----------------
        private void Install(string variant)
        {
            if (win64 == null) { SetStatus(L("未找到游戏：请把本文件夹放进游戏根目录后再操作。", "Game not found: put this folder into the game root directory and try again."), true); return; }
            if (GameRunning())
            {
                SetStatus(L("请先关闭游戏再安装。安装需要替换启动程序，游戏运行中无法替换。", "Please close the game before installing. Installation replaces the launcher, which cannot be done while the game is running."), true);
                return;
            }

            Mode mode = DetectMode();
            string notice = BuildNotice(mode);
            if (!SuppressDialogs)
            {
                DialogResult r = MessageBox.Show(
                    L("即将安装：", "About to install: ") + (variant == "enhanced" ? L("强化版", "Enhanced") : L("普通版", "Standard")) + Environment.NewLine + Environment.NewLine
                    + notice + Environment.NewLine + Environment.NewLine + L("继续安装吗？", "Continue?"),
                    L("安装前确认", "Confirm before installing"), MessageBoxButtons.YesNo, MessageBoxIcon.Question);
                if (r != DialogResult.Yes) { SetStatus(L("已取消，没有做任何改动。", "Cancelled; nothing was changed."), false); return; }
            }

            try
            {
                string payload = FindPayloadDir(@"payload\" + variant + @"\Scripts");
                if (payload == null) { SetStatus(L("安装失败：缺少 payload\\", "Install failed: missing payload\\") + variant, true); return; }

                StringBuilder state = new StringBuilder();
                state.AppendLine("mode=" + mode.ToString());
                state.AppendLine("variant=" + variant);

                if (mode == Mode.IntegratedPackage)
                {
                    string pkg = IntegratedPackageDir();
                    string extra = Path.Combine(pkg, "ue4ss-mods");
                    Directory.CreateDirectory(extra);
                    string target = Path.Combine(extra, ModName);
                    if (Directory.Exists(target)) Directory.Delete(target, true);
                    CopyDirectory(payload, Path.Combine(target, "Scripts"));
                    state.AppendLine("pkg=" + pkg);

                    string features = Path.Combine(pkg, "features.ini");
                    string bak = features + FeaturesBackupSuffix;
                    if (File.Exists(features) && !File.Exists(bak))
                    {
                        File.Copy(features, bak, true);
                        state.AppendLine("featuresBackup=" + bak);
                        string text = File.ReadAllText(features, Encoding.UTF8);
                        string updated = Regex.Replace(text, "missile_mode\\s*=\\s*\\w+", "missile_mode=none");
                        if (updated != text) File.WriteAllText(features, updated, new UTF8Encoding(false));
                    }
                }
                else
                {
                    string modsDir = Path.Combine(win64, @"ue4ss\Mods");
                    if (!Directory.Exists(Path.Combine(win64, "ue4ss")))
                    {
                        string runtime = FindPayloadDir(@"payload\runtime\win64");
                        if (runtime == null) { SetStatus(L("安装失败：缺少运行库 payload\\runtime", "Install failed: missing runtime payload\\runtime"), true); return; }
                        CopyDirectory(runtime, win64);
                        File.WriteAllText(Path.Combine(win64, "steam_appid.txt"), AppId, Encoding.ASCII);
                        File.WriteAllText(Path.Combine(win64, Marker), variant, Encoding.ASCII);
                        state.AppendLine("runtimeInstalled=1");
                    }
                    Directory.CreateDirectory(modsDir);
                    string target = Path.Combine(modsDir, ModName);
                    if (Directory.Exists(target)) Directory.Delete(target, true);
                    CopyDirectory(payload, Path.Combine(target, "Scripts"));
                    EnsureModsEntry(Path.Combine(modsDir, "mods.txt"));

                    string err;
                    if (!InstallLauncherSwap(out err))
                    {
                        SetStatus(L("Mod 文件已复制，但替换启动程序失败：", "Mod files were copied, but replacing the launcher failed: ") + err
                                + L("。游戏仍可用 Steam 正常启动，但 Mod 不会生效。", ". The game still starts normally from Steam, but the mod will not take effect."), true);
                        return;
                    }
                    state.AppendLine("launcherReplaced=1");
                }

                File.WriteAllText(Path.Combine(win64, StateFile), state.ToString(), Encoding.UTF8);

                string done = L("已安装：", "Installed: ") + (variant == "enhanced" ? L("强化版", "Enhanced") : L("普通版", "Standard")) + "。";
                if (mode == Mode.IntegratedPackage) done += L("现在用整合包原来的方式从 Steam 启动即可。", "From now on, launch from Steam the same way the integrated package does.");
                else done += L("现在直接在 Steam 点「开始游戏」即可。", "From now on just press Play in Steam.");
                SetStatus(done, false);
            }
            catch (Exception ex)
            {
                SetStatus(L("安装失败：", "Install failed: ") + ex.Message, true);
            }
        }

        private void Restore()
        {
            if (win64 == null) { SetStatus(L("未找到游戏：请把本文件夹放进游戏根目录后再操作。", "Game not found: put this folder into the game root directory and try again."), true); return; }
            if (GameRunning())
            {
                SetStatus(L("请先关闭游戏再还原。", "Please close the game before restoring."), true);
                return;
            }
            try
            {
                string statePath = Path.Combine(win64, StateFile);
                string mode = "standalone";
                string pkg = null;
                string featuresBackup = null;
                bool launcherReplaced = false;
                if (File.Exists(statePath))
                {
                    foreach (string line in File.ReadAllLines(statePath))
                    {
                        int i = line.IndexOf('=');
                        if (i <= 0) continue;
                        string k = line.Substring(0, i).Trim();
                        string v = line.Substring(i + 1).Trim();
                        if (k == "mode") mode = v;
                        else if (k == "pkg") pkg = v;
                        else if (k == "featuresBackup") featuresBackup = v;
                        else if (k == "launcherReplaced") launcherReplaced = (v == "1");
                    }
                }

                StringBuilder removed = new StringBuilder();
                bool optOk = true;
                string err = null;

                if (mode == "IntegratedPackage" && !string.IsNullOrEmpty(pkg) && Directory.Exists(pkg))
                {
                    string target = Path.Combine(pkg, @"ue4ss-mods\" + ModName);
                    if (Directory.Exists(target)) { Directory.Delete(target, true); removed.Append(L("附加 Mod", "add-on mod")); }
                    if (!string.IsNullOrEmpty(featuresBackup) && File.Exists(featuresBackup))
                    {
                        File.Copy(featuresBackup, Path.Combine(pkg, "features.ini"), true);
                        File.Delete(featuresBackup);
                        removed.Append(removed.Length > 0 ? L(" + 导弹增强设置", " + missile enhancement settings") : L("导弹增强设置", "missile enhancement settings"));
                    }
                }

                if (launcherReplaced && !RestoreLauncher(out err))
                {
                    optOk = false;
                }
                else if (launcherReplaced)
                {
                    removed.Append(removed.Length > 0 ? L(" + 启动程序", " + launcher") : L("启动程序", "launcher"));
                }

                string modDir = Path.Combine(win64, @"ue4ss\Mods\" + ModName);
                if (Directory.Exists(modDir)) { Directory.Delete(modDir, true); removed.Append(removed.Length > 0 ? L(" + Mod 文件", " + mod files") : L("Mod 文件", "mod files")); }
                RemoveModsEntry(Path.Combine(win64, @"ue4ss\Mods\mods.txt"));

                string marker = Path.Combine(win64, Marker);
                if (File.Exists(marker))
                {
                    File.Delete(marker);
                    foreach (string f in new string[] { "dwmapi.dll", "steam_appid.txt" })
                    {
                        string p = Path.Combine(win64, f);
                        if (File.Exists(p)) File.Delete(p);
                    }
                    string ue4ss = Path.Combine(win64, "ue4ss");
                    if (Directory.Exists(ue4ss)) Directory.Delete(ue4ss, true);
                    removed.Append(removed.Length > 0 ? L(" + 运行库", " + runtime") : L("运行库", "runtime"));
                }

                if (File.Exists(statePath)) File.Delete(statePath);

                string msg = L("已还原：", "Restored: ") + (removed.Length > 0 ? L("已移除", "Removed") + removed + "。" : L("没有需要移除的内容。", "Nothing to remove."));
                if (!optOk) msg += L("（启动程序恢复失败：", "(launcher restore failed: ") + err + "）";
                SetStatus(msg, optOk);
            }
            catch (Exception ex)
            {
                SetStatus(L("还原失败：", "Restore failed: ") + ex.Message, true);
            }
        }

        // ---------------- 启动程序接管 ----------------
        private string GameRoot()
        {
            return Path.GetFullPath(Path.Combine(win64, @"..\..\.."));
        }

        private bool InstallLauncherSwap(out string error)
        {
            error = null;
            string launcher = FindPayloadFile(@"payload\launcher\start_protected_game.exe");
            if (launcher == null) { error = L("缺少 payload\\launcher\\start_protected_game.exe", "missing payload\\launcher\\start_protected_game.exe"); return false; }
            string target = Path.Combine(GameRoot(), ProtectedExe);
            string backup = target + ProtectedBackupSuffix;
            try
            {
                if (!File.Exists(backup) && File.Exists(target)) File.Copy(target, backup, true);
                File.Copy(launcher, target, true);
                return true;
            }
            catch (Exception ex)
            {
                error = ex.Message;
                return false;
            }
        }

        private bool RestoreLauncher(out string error)
        {
            error = null;
            string target = Path.Combine(GameRoot(), ProtectedExe);
            string backup = target + ProtectedBackupSuffix;
            try
            {
                if (!File.Exists(backup)) return true;
                File.Copy(backup, target, true);
                File.Delete(backup);
                return true;
            }
            catch (Exception ex)
            {
                error = ex.Message;
                return false;
            }
        }

        // ---------------- Steam 配置（只读，用于识别整合包）----------------
        private static string SteamRoot()
        {
            string env = Environment.GetEnvironmentVariable("AC8_STEAM_ROOT");
            if (!string.IsNullOrEmpty(env) && Directory.Exists(env)) return env;
            try
            {
                using (RegistryKey k = Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam"))
                {
                    if (k != null)
                    {
                        object v = k.GetValue("SteamPath");
                        if (v != null)
                        {
                            string p = v.ToString().Replace('/', '\\');
                            if (Directory.Exists(p)) return p;
                        }
                    }
                }
            }
            catch { }
            var cands = new System.Collections.Generic.List<string>();
            string pf86 = Environment.GetEnvironmentVariable("ProgramFiles(x86)");
            string pf = Environment.GetEnvironmentVariable("ProgramFiles");
            if (!string.IsNullOrEmpty(pf86)) cands.Add(Path.Combine(pf86, "Steam"));
            if (!string.IsNullOrEmpty(pf)) cands.Add(Path.Combine(pf, "Steam"));
            try
            {
                foreach (DriveInfo d in DriveInfo.GetDrives())
                {
                    try
                    {
                        if (d.DriveType != DriveType.Fixed) continue;
                        cands.Add(Path.Combine(d.RootDirectory.FullName, "Steam"));
                    }
                    catch { }
                }
            }
            catch { }
            foreach (string p in cands)
                if (!string.IsNullOrEmpty(p) && Directory.Exists(Path.Combine(p, "userdata"))) return p;
            return null;
        }

        private static string ActiveUserDir(string steamRoot)
        {
            string userdata = Path.Combine(steamRoot, "userdata");
            if (!Directory.Exists(userdata)) return null;
            uint active = 0;
            try
            {
                using (RegistryKey k = Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam\ActiveProcess"))
                {
                    if (k != null)
                    {
                        object v = k.GetValue("ActiveUser");
                        if (v != null) active = (uint)Convert.ToInt64(v);
                    }
                }
            }
            catch { }
            if (active > 0)
            {
                string dir = Path.Combine(userdata, active.ToString());
                if (Directory.Exists(dir)) return dir;
            }
            string[] dirs = Directory.GetDirectories(userdata);
            if (dirs.Length == 1) return dirs[0];
            return null;
        }

        private static string LocalConfigPath()
        {
            string steam = SteamRoot();
            if (steam == null) return null;
            string user = ActiveUserDir(steam);
            if (user == null) return null;
            string f = Path.Combine(user, @"config\localconfig.vdf");
            return File.Exists(f) ? f : null;
        }

        private string CurrentLaunchOption()
        {
            string f = LocalConfigPath();
            if (f == null) return null;
            return ReadLaunchOption(File.ReadAllText(f, Encoding.UTF8));
        }

        private static bool FindAppBlock(string text, out int blockStart, out int blockEnd)
        {
            blockStart = blockEnd = -1;
            Match m = Regex.Match(text, "\"" + AppId + "\"\\s*\\{");
            if (!m.Success) return false;
            int depth = 1, i = m.Index + m.Length;
            bool quoted = false, esc = false;
            while (i < text.Length)
            {
                char c = text[i];
                if (esc) esc = false;
                else if (quoted && c == '\\') esc = true;
                else if (c == '"') quoted = !quoted;
                else if (!quoted && c == '{') depth++;
                else if (!quoted && c == '}')
                {
                    depth--;
                    if (depth == 0) break;
                }
                i++;
            }
            if (depth != 0) return false;
            blockStart = m.Index + m.Length;
            blockEnd = i;
            return true;
        }

        private static string ReadLaunchOption(string text)
        {
            int s, e;
            if (!FindAppBlock(text, out s, out e)) return null;
            string body = text.Substring(s, e - s);
            Match m = Regex.Match(body, "\"LaunchOptions\"\\s*\"((?:\\\\.|[^\"\\\\])*)\"");
            return m.Success ? Regex.Unescape(m.Groups[1].Value) : "";
        }

        // ---------------- 文件 ----------------
        private static void EnsureModsEntry(string modsTxt)
        {
            string[] lines = File.Exists(modsTxt) ? File.ReadAllLines(modsTxt) : new string[0];
            StringBuilder sb = new StringBuilder();
            foreach (string line in lines)
            {
                if (line.Trim().StartsWith(ModName, StringComparison.OrdinalIgnoreCase)) continue;
                if (line.Trim().Length == 0) continue;
                sb.AppendLine(line.TrimEnd());
            }
            sb.AppendLine(ModName + " : 1");
            File.WriteAllText(modsTxt, sb.ToString(), Encoding.ASCII);
        }

        private static void RemoveModsEntry(string modsTxt)
        {
            if (!File.Exists(modsTxt)) return;
            StringBuilder sb = new StringBuilder();
            foreach (string line in File.ReadAllLines(modsTxt))
            {
                if (line.Trim().StartsWith(ModName, StringComparison.OrdinalIgnoreCase)) continue;
                sb.AppendLine(line.TrimEnd());
            }
            File.WriteAllText(modsTxt, sb.ToString(), Encoding.ASCII);
        }

        private static void CopyDirectory(string source, string dest)
        {
            Directory.CreateDirectory(dest);
            foreach (string dir in Directory.GetDirectories(source, "*", SearchOption.AllDirectories))
                Directory.CreateDirectory(dir.Replace(source, dest));
            foreach (string file in Directory.GetFiles(source, "*", SearchOption.AllDirectories))
            {
                string target = file.Replace(source, dest);
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                File.Copy(file, target, true);
            }
        }

        public static void SelfTest(string dir)
        {
            InstallerForm f = new InstallerForm();
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("base  = " + dir);
            sb.AppendLine("win64 = " + (f.win64 == null ? "(not found)" : f.win64));
            sb.AppendLine("mode  = " + (f.win64 == null ? "n/a" : f.DetectMode().ToString()));
            sb.AppendLine("payload enhanced = " + (f.FindPayloadDir(@"payload\enhanced\Scripts") != null));
            sb.AppendLine("payload normal   = " + (f.FindPayloadDir(@"payload\normal\Scripts") != null));
            sb.AppendLine("payload runtime  = " + (f.FindPayloadDir(@"payload\runtime\win64") != null));
            sb.AppendLine("payload launcher = " + (f.FindPayloadFile(@"payload\launcher\start_protected_game.exe") != null));
            sb.AppendLine("notice:");
            sb.AppendLine(f.PublicNotice() ?? "(none)");
            File.WriteAllText(Path.Combine(dir, "selftest.txt"), sb.ToString(), Encoding.UTF8);
        }

        [STAThread]
        public static void Main(string[] args)
        {
            string dir = Path.GetDirectoryName(Application.ExecutablePath);
            if (args.Length > 0 && args[0].Equals("--selftest", StringComparison.OrdinalIgnoreCase))
            {
                SelfTest(dir);
                return;
            }
            if (args.Length > 0 && args[0].Equals("--notice", StringComparison.OrdinalIgnoreCase))
            {
                InstallerForm f = new InstallerForm();
                File.WriteAllText(Path.Combine(dir, "cli-result.txt"), f.PublicNotice() ?? "(none)", Encoding.UTF8);
                return;
            }
            if (args.Length > 1 && args[0].Equals("--install", StringComparison.OrdinalIgnoreCase))
            {
                InstallerForm f = new InstallerForm();
                f.SuppressDialogs = true;
                f.DoInstall(args[1]);
                File.WriteAllText(Path.Combine(dir, "cli-result.txt"), f.LastStatus, Encoding.UTF8);
                return;
            }
            if (args.Length > 0 && args[0].Equals("--restore", StringComparison.OrdinalIgnoreCase))
            {
                InstallerForm f = new InstallerForm();
                f.SuppressDialogs = true;
                f.DoRestore();
                File.WriteAllText(Path.Combine(dir, "cli-result.txt"), f.LastStatus, Encoding.UTF8);
                return;
            }
            Application.EnableVisualStyles();
            Application.Run(new InstallerForm());
        }
    }
}
