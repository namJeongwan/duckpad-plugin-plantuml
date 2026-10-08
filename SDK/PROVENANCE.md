# Duckpad host contract snapshot

Copied from Duckpad commit [`de5a2f00ac682ab180f9a5d431d45e664aacde91`](https://github.com/namJeongwan/duckpad/commit/de5a2f00ac682ab180f9a5d431d45e664aacde91) for host API 1.4.0.
These files let this plugin build independently; runtime rendering stays in Duckpad.
The corresponding host release is 0.10.0. Source repository: https://github.com/namJeongwan/duckpad.
The host release is reviewed separately; these SHA-256 values identify the exact SDK snapshot.

Do not edit the snapshot to invent host behavior. Update it from a matching host SDK.

## SHA-256

```text
3513821b3445a45e851f49dad03456b5de26dbc4b5ba27a863c4e94d5eb2e254  DuckpadNative/Swift/DuckpadHost.swift
48481a24e666f89356c240850dcedd86c41545631de6422dbf2ae7df9a786722  DuckpadNative/include/DuckpadNative.h
f32eeca30e35bdfc557aa07b595721188a8c025fdf464a00df23be0dfb11e473  DuckpadNative/include/module.modulemap
b9453b3599d06e4b8be831ed0a00eac3f952c47b81482cd1684ee25f60f2109f  DuckpadRuntime/NativeInstallerXPCProtocol.swift
0bfab4701241fe5e47e9a4046f89840536b046d308e5489efc885b56feb86244  DuckpadRuntime/PlantUMLRequest.swift
```
