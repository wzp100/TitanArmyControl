# TitanArmyControl architecture

## Goal

TitanArmyControl targets macOS and Windows from one behavioral contract. The UI
may follow each operating system's conventions, but monitor capabilities,
register mappings, validation rules, write ordering, and verification behavior
must stay identical.

## Layers

1. `shared/`
   Platform-neutral JSON contracts and protocol vectors. This is the source of
   truth for model identity, VCP mappings, ranges, enum values, timing, and DDC
   frame examples.
2. `Sources/TitanArmyCore/`
   The macOS implementation of the shared contract. It contains no SwiftUI.
3. `windows/src/TitanArmyControl.Core/`
   The Windows/.NET implementation of the same contract. It contains no WinUI,
   Reactor, registry, P/Invoke, or other platform-specific code.
4. Platform adapters
   - macOS: `Sources/TitanArmyCore/DDC/IOAVTransport.swift`
   - Windows: `windows/src/TitanArmyControl.Platform.Windows/`
5. UI
   - macOS: SwiftUI under `Sources/TitanArmyControlApp/`
   - Windows: Microsoft.UI.Reactor under
     `windows/src/TitanArmyControl.Windows/`

The dependency direction is always:

```text
UI -> Application -> Protocol / Controller -> Transport interface -> OS adapter
```

UI code never reads or writes a VCP register directly.

## Shared business invariants

- Unknown registers are never written.
- Writes are range-checked against the display's reported maximum.
- Tone changes fail while HDR locks the panel.
- Slider values are validated before any part of a multi-write command is sent.
- Vendor commands use the selector-then-target ordering: `0x99`, then target.
- The HDR vendor command waits 1.5 seconds before the next DDC operation.
- Game Assistant overlay enable commands clear mutually exclusive overlays.
- A repeated official value may be skipped using a register-keyed cache.
- A failed multi-write operation is reported; it is never presented as success.

## Consistency enforcement

Both platform test suites read `shared/profile.contract.json` and verify their
compiled constants against it. DDC framing implementations use
`shared/ddc-vectors.json`. A change to a register or enum must therefore update
the shared contract and both implementations in the same commit.

The Windows physical transport uses `dxva2.dll`, so it does not transmit the
macOS I2C frame itself. The shared frame vectors still validate the portable
protocol model and are used by diagnostics or future low-level transports.

## Hardware-dependent capabilities

Capabilities are described explicitly rather than inferred:

- `Ddc`: available through IOAVService on macOS and DXVA2 on Windows.
- `Hid`: vendor lighting, animation, and any command not exposed through DDC.
  It requires the monitor's USB data channel. Do not fake success when absent.
- `SystemHdr`: implemented by the operating system adapter.

The UI must distinguish unsupported, unavailable, and unverified features.

