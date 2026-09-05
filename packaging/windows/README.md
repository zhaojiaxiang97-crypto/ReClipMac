# Windows portable package

This directory contains the Windows packaging entry point. It creates a portable folder that includes the Qt runtime, QML imports, platform plugins, `yt-dlp`, FFmpeg, and license notices.

From the repository root:

```powershell
.\packaging\windows\package.ps1 -Configuration Release
```

The default output is `.artifacts/windows/ReClip-Release`. Build files are kept under `.build/package-windows-release`. To use another Qt or runtime-tool installation, set `RECLIP_QT_ROOT` and `RECLIP_TOOL_BIN` before invoking the script.

The script intentionally refuses to overwrite an existing output directory. Remove an old package explicitly or pass a new `-OutputDirectory`.

The packaged application searches `<package>\bin` before the system `PATH`, so a clean Windows machine does not need Qt, CMake, Visual Studio, or globally installed download tools. A real network download should be tested with a user-authorized, non-DRM URL before publishing a release.
