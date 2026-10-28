# AC8 UGBL Replacement - source (published for verification)

Ace Combat 8 mod: replaces the standard missile (MSL) model with the UGBL guided
bomb and adjusts damage / blast radius. The "Enhanced" edition additionally ports
the full missile performance tuning; the "Standard" edition changes the model,
damage and blast radius only.

## What is actually distributed

The released mod is **plain Lua source for UE4SS**, delivered as a drag-and-drop
zip for ACE8 Mod Launcher. The zip contains no executable, no DLL and no archive
it needs to unpack into the game:

```
AC8MissileBomb\            (Enhanced)  or  AC8MissileBomb-Normal\  (Standard)
    enabled.txt            empty marker that tells UE4SS to load the mod
    README.txt             install / verify / uninstall, English then Chinese
    Scripts\               the mod itself - plain text Lua
```

Install: drag the zip onto the ACE8 Mod Launcher window (or copy the folder to
`<game>\Game\Binaries\Win64\ue4ss\Mods\`), make sure the mod is switched on,
choose "Modded" and press Play.

The scripts in `mod-scripts\` in this repository are byte-identical to the ones
inside the released zip, so the mod can be read in full before installing.

## What it does at runtime

- offline interlock: refuses to load unless the anti-cheat is disabled and the
  game is the offline build, so it cannot silently apply in an online session
- swaps the model on the five player missile blueprints and on their spawned
  instances (`StaticMesh` + `HiddenMissileMesh`)
- writes damage / blast radius / (Enhanced only) the performance values into
  `DT_WeaponSettings` rows `C.STORY` and `EASY` - difficulty rows, so every
  aircraft's missile is affected regardless of the model swap
- re-applies idempotently at every mission start

## What it does not do

- no network access of any kind (no downloader, no telemetry, no update check)
- no registry writes
- no changes to Steam configuration (nothing is read or written)
- no game file on disk is modified - everything is done in memory at runtime
- no services, scheduled tasks, drivers or startup entries

## Reading the log

`<game>\Game\Binaries\Win64\ue4ss\UE4SS.log`, lines starting with `[AC8MB]`:

```
[AC8MB] guard=offline-ok stage=1 build=1.2 variant='enhanced'
[AC8MB] WEAPONS APPLIED verified=... written=... vfx_fields=15/15
[AC8MB] VISUALS cdo changed=10 classes=5
[AC8MB] VISUALS actor BP_plwp_msl_xx_C changed=2 mesh=SM_w_ugbl_r0 ...
```

- `changed=10` is the full value: 5 missile blueprints x 2 model components.
  Anything from 1 to 10 means the swap applied; 0 or a missing line means
  something else overrode the model.
- `vfx_fields=15/15` counts weapon explosion-effect fields and is unrelated to
  `changed=`; it was renamed from `vfx_changed=` precisely so the two numbers are
  not confused (an earlier readme sample wrongly showed 15 for `changed=`).

## Repository layout

```
mod-scripts\             the released Lua mod (UE4SS), plain text
installer_bilingual.cs   LEGACY, not distributed: WinForms installer, one C# file
launcher.cs              LEGACY, not distributed: offline launcher
build.cmd                LEGACY: builds the installer with the Windows C# compiler
make_bilingual.ps1       LEGACY: translation-table generator (reproducibility)
zh_order.txt, en_order.txt  LEGACY: string tables used by the generator
```

## Why there is no installer any more

An earlier release bundled a self-built, unsigned .NET executable plus a UE4SS
runtime DLL set, and an offline launcher that replaced `start_protected_game.exe`.
That package was rejected by the Nexus Mods review as an executable payload, and
self-built executables that copy files next to a game and replace a game launcher
also match the generic "mod loader / dropper" heuristic of antivirus engines.

Current releases therefore ship scripts only, and the game needs the loader
(ACE8 Mod Launcher / UE4SS) that mod users already have. The installer source is
kept in this repository unchanged for auditability, with the old hash:

```
AC8-UGBL-Installer.exe (no longer distributed)
  size      31744 bytes
  SHA256    775C681116FFA3C5F47D17D7957F00306154DB51B85CBB713A3231AADE3682A2
  signature none (self-built, no code-signing certificate)
```

Build instructions for it (any Windows install already has the compiler):

```
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe ^
    /out:AC8-UGBL-Installer.exe /r:System.Windows.Forms.dll /r:System.Drawing.dll ^
    installer_bilingual.cs
```

## Credits

Mod scripts, installer source and documentation were written with the help of
DeepSeek (AI assistant). Published as source so the mod stays auditable.

## Licence

Source is published for verification of the mod distributed on Nexus Mods. All
rights reserved; redistribution or reuse requires permission.
