$ErrorActionPreference = 'Stop'
$dir = 'D:\deepseek工作区\AC8-UGBL-Replacement-src'
$src = Join-Path $dir 'installer.cs.txt'
$t = (Get-Content $src -Raw -Encoding UTF8) -replace "`r`n", "`n"

$zhLines = Get-Content (Join-Path $dir 'zh_order.txt') -Encoding UTF8 | Where-Object { $_ -match "`t" }
$enLines = Get-Content (Join-Path $dir 'en_order.txt') -Encoding UTF8
Write-Output ("zh entries: {0}  en lines: {1}" -f $zhLines.Count, $enLines.Count)

$zh = @()
foreach ($l in $zhLines) { $zh += ($l -split "`t", 2)[1] }

$fields = @'
        private Label status;
        private string baseDir;
        private string win64;

        private static bool En = false;
        private Button bLang;
        private static string L(string zh, string en) { return En ? en : zh; }
'@
$t = $t.Replace("        private Label status;`n        private string baseDir;`n        private string win64;`n", $fields.Replace("`r`n", "`n") + "`n")

$t = $t.Replace("        public InstallerForm()`n        {`n", "        private void BuildUi()`n        {`n            SuspendLayout();`n            Controls.Clear();`n")

$tail = @'

            bLang = new Button();
            bLang.Text = En ? "\u4e2d\u6587" : "English";
            bLang.SetBounds(516, 10, 106, 26);
            bLang.Click += delegate { En = !En; BuildUi(); };
            Controls.Add(bLang);
            ResumeLayout();

        }

        public InstallerForm()
        {
            baseDir = Path.GetDirectoryName(Application.ExecutablePath);
            win64 = FindWin64(baseDir);
            BuildUi();
        }

        public string LastStatus
'@
$t = $t.Replace("`n        public string LastStatus", $tail.Replace("`r`n", "`n"))

$missing = @()
for ($i = 0; $i -lt $zh.Count; $i++) {
    $zhs = $zh[$i]
    $ens = $enLines[$i]
    $needle = '"' + $zhs + '"'
    if (-not $t.Contains($needle)) { $missing += $zhs; continue }
    $repl = 'L("' + $zhs + '", "' + $ens + '")'
    $t = $t.Replace($needle, $repl)
}
Write-Output ("missing: {0}" -f $missing.Count)
$missing | ForEach-Object { Write-Output ("  MISS {0}" -f $_) }

$out = Join-Path $dir 'installer_bilingual.cs'
[IO.File]::WriteAllText($out, $t, (New-Object Text.UTF8Encoding($true)))
Write-Output ("written {0} bytes" -f (Get-Item $out).Length)
