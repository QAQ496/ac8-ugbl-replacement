# AC8 UGBL Replacement - source (published for verification)

Ace Combat 8 mod: replaces the standard missile (MSL) model with the UGBL guided
bomb and adjusts damage / blast radius (the "Enhanced" variant additionally ports
the full missile performance tuning). The installer that ships with the mod is a
single-file .NET Framework WinForms program; this repository contains its complete
source so the executable can be audited.

## Repository layout

```
installer_bilingual.cs   the whole installer, one C# file (English/Chinese UI toggle)
launcher.cs              the offline launcher that replaces start_protected_game.exe
build.cmd                builds AC8-UGBL-Installer.exe with the Windows C# compiler
make_bilingual.ps1       generator that applies the translation tables (reproducibility)
zh_order.txt             Chinese string table used by the generator
en_order.txt             English string table used by the generator
mod-scripts\             the Lua mod itself (UE4SS scripts), plain text
```

## What the installer does

1. Finds the game folder: walks up to five parent directories looking for
   `Game\Binaries\Win64\AceCombat8.exe`.
2. Detects the environment: an existing "mouse flight" integrated package (by
   *reading* the current Steam launch option), an existing UE4SS runtime, or a
   clean installation.
3. Copies files from the `payload\` folder next to the executable:
   - `payload\enhanced\` or `payload\normal\` ->
     `<game>\Game\Binaries\Win64\ue4ss\Mods\AC8MissileBomb\`
   - `payload\runtime\` -> `<game>\Game\Binaries\Win64\` (only when no UE4SS is
     present yet)
4. Replaces `<game>\start_protected_game.exe` with the offline launcher built from
   `launcher.cs`, keeping the original as `start_protected_game.exe.ac8ugbl.bak`.
5. Stores what was changed in `AC8-UGBL-state.txt`; "Restore game" puts every item
   back exactly as recorded.

## What it does not do

- no network access of any kind (no downloader, no telemetry, no update check)
- no registry writes (Steam library folders are only read to locate the game)
- no changes to Steam configuration (launch options are read, never written)
- no persistence: no services, no scheduled tasks, no drivers, no startup entries
- no packing or encryption of its own files

## Build

Any normal Windows installation already contains the compiler (part of the .NET
Framework 4.x), so no SDK download is required:

```
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe ^
    /out:AC8-UGBL-Installer.exe /r:System.Windows.Forms.dll /r:System.Drawing.dll ^
    installer_bilingual.cs
```

or simply run `build.cmd`, which does the same and prints the SHA-256 of the result.

Byte-for-byte equality with the released executable is not expected (the .NET
Framework compiler embeds a fresh module version id on every build); behaviour and
the set of files it writes are identical.

## Released executable

```
AC8-UGBL-Installer.exe
  size      31744 bytes
  SHA256    775C681116FFA3C5F47D17D7957F00306154DB51B85CBB713A3231AADE3682A2
  MD5       6341553522E57CE1F2486B3A5D2E4B8D
  signature none (self-built, no code-signing certificate)
```

## Why antivirus heuristics flag it

Self-built, unsigned .NET executables that copy files next to a game and replace a
game launcher match the generic "mod loader / dropper" heuristic. There is no
packer and no obfuscation: the source above is the complete program.

If the executable is undesirable, the mod can be installed without it: copy
`payload\enhanced\` into `<game>\Game\Binaries\Win64\ue4ss\Mods\AC8MissileBomb\`.

## Credits

Installer, launcher, Lua mod and documentation were written with the help of
DeepSeek (AI assistant). Published as source so the mod stays auditable.

## Licence

Source is published for verification of the mod distributed on Nexus Mods. All
rights reserved; redistribution or reuse requires permission.
