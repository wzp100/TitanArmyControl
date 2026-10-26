# TitanArmyControl for Windows

Microsoft.UI.Reactor shell for TitanArmyControl. The business layer in
`src/TitanArmyControl.Core` is identical to the macOS core and is verified
against the shared contract in `../shared/`.

## Requirements

- Windows 10 22621 or later (x64)
- .NET 10 SDK
- Visual Studio 2022 with the Windows App SDK workload, or the standalone
  `Microsoft.WindowsAppSDK` tooling installed by NuGet restore
- Windows Developer Mode (only needed for unpackaged F5 debugging)

## Build

```powershell
cd windows
dotnet build TitanArmyControl.sln -c Release -p:Platform=x64
```

Output: `src/TitanArmyControl.Windows/bin/x64/Release/net10.0-windows10.0.22621.0/TitanArmyControl.exe`

## Tests

```powershell
dotnet test tests/TitanArmyControl.Core.Tests -c Release
```

## macOS cross-compilation

The C# sources can be type-checked on macOS. The Windows App SDK's manifest
merge and PRI tooling are Windows-only binaries, so:

```sh
cd windows
~/.dotnet/dotnet build src/TitanArmyControl.Windows \
  -c Release -p:Platform=x64 -t:Compile \
  -p:ManifestTool=../scripts/win-manifest-stub.sh
```

`-t:Compile` stops before the Windows-only packaging steps. The resulting
bundle is not runnable; always produce release builds on Windows.

## Architecture

- `src/TitanArmyControl.Core`: protocol, controller, application facade. No
  WinUI, Reactor, P/Invoke, or registry types.
- `src/TitanArmyControl.Platform.Windows`: `dxva2.dll` DDC/CI transport and
  display catalog. Reports vendor HID as unavailable until the USB data
  channel and protocol are verified.
- `src/TitanArmyControl.Windows`: Reactor UI only. Seven pages mirror the
  official VIEW MORE WIDGET layout: Scene, GAME+, Dark Oracle, Basic, OLED
  Care, Customer Service, Official Store.

Unknown VCP registers are never written. Features that need the vendor USB
HID channel are shown as unavailable instead of silently failing.
