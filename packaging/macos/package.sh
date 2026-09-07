#!/usr/bin/env bash

set -euo pipefail

configuration="${1:-Release}"
script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/../.." && pwd)"
build_directory="${RECLIP_BUILD_DIR:-${repository_root}/.build/package-macos-${configuration}}"
output_directory="${RECLIP_OUTPUT_DIR:-${repository_root}/.artifacts/macos/ReClip-${configuration}.app}"
qt_root="${RECLIP_QT_ROOT:-}"
tool_bin="${RECLIP_TOOL_BIN:-}"

die() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

resolve_tool() {
    local tool_name="$1"
    local candidate

    if [[ -n "${tool_bin}" ]]; then
        candidate="${tool_bin}/${tool_name}"
        if [[ -x "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    fi

    candidate="$(command -v "${tool_name}" || true)"
    [[ -n "${candidate}" && -x "${candidate}" ]] || die "找不到 ${tool_name}，请设置 RECLIP_TOOL_BIN 或先安装该工具"
    printf '%s\n' "${candidate}"
}

if [[ -n "${qt_root}" ]]; then
    qt_cmake="${qt_root}/bin/qt-cmake"
    macdeployqt="${qt_root}/bin/macdeployqt"
else
    qt_cmake="$(command -v qt-cmake || true)"
    macdeployqt="$(command -v macdeployqt || true)"
fi

[[ -x "${qt_cmake}" ]] || die "找不到 qt-cmake，请设置 RECLIP_QT_ROOT"
[[ -x "${macdeployqt}" ]] || die "找不到 macdeployqt，请设置 RECLIP_QT_ROOT"
[[ ! -e "${output_directory}" ]] || die "输出目录已存在，拒绝覆盖：${output_directory}"

yt_dlp="$(resolve_tool yt-dlp)"
ffmpeg="$(resolve_tool ffmpeg)"
ffprobe="$(resolve_tool ffprobe)"

"${qt_cmake}" -S "${repository_root}" -B "${build_directory}" -DCMAKE_BUILD_TYPE="${configuration}" -DBUILD_TESTING=OFF
cmake --build "${build_directory}" --config "${configuration}" --parallel

source_app="${build_directory}/ReClip.app"
if [[ ! -d "${source_app}" ]]; then
    source_app="${build_directory}/${configuration}/ReClip.app"
fi
[[ -d "${source_app}" ]] || die "构建完成但没有找到 ReClip.app"

mkdir -p "$(dirname -- "${output_directory}")"
cp -R "${source_app}" "${output_directory}"

bundle_bin="${output_directory}/Contents/Resources/bin"
license_directory="${output_directory}/Contents/Resources/licenses"
mkdir -p "${bundle_bin}" "${license_directory}"
cp -L "${yt_dlp}" "${bundle_bin}/yt-dlp"
cp -L "${ffmpeg}" "${output_directory}/Contents/MacOS/ffmpeg"
cp -L "${ffprobe}" "${output_directory}/Contents/MacOS/ffprobe"
chmod 755 "${bundle_bin}/yt-dlp" "${output_directory}/Contents/MacOS/ffmpeg" "${output_directory}/Contents/MacOS/ffprobe"
cat > "${bundle_bin}/ffmpeg" <<'EOF'
#!/bin/sh
exec "$(dirname "$0")/../../MacOS/ffmpeg" "$@"
EOF
cat > "${bundle_bin}/ffprobe" <<'EOF'
#!/bin/sh
exec "$(dirname "$0")/../../MacOS/ffprobe" "$@"
EOF
chmod 755 "${bundle_bin}/ffmpeg" "${bundle_bin}/ffprobe"
cp "${repository_root}/LICENSE" "${license_directory}/LICENSE"
cp "${repository_root}/NOTICE" "${license_directory}/NOTICE"
cp "${repository_root}/packaging/macos/THIRD_PARTY_NOTICES.md" "${output_directory}/Contents/Resources/THIRD_PARTY_NOTICES.md"

ffmpeg_license="$(find "$(dirname -- "${ffmpeg}")" -maxdepth 2 -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' \) -print -quit 2>/dev/null || true)"
if [[ -n "${ffmpeg_license}" ]]; then
    cp "${ffmpeg_license}" "${license_directory}/FFmpeg-LICENSE"
else
    printf '保留 FFmpeg 构建目录中的许可证文件；发布前请核对实际构建的 LGPL/GPL 配置。\n' > "${license_directory}/FFmpeg-LICENSE-LOCATION.txt"
fi

# Also deploy dylibs referenced by bundled FFmpeg binaries. yt-dlp is expected
# to be a standalone macOS binary or a self-contained executable.
"${macdeployqt}" "${output_directory}" \
    -qmldir="${repository_root}/qml" \
    -executable="${output_directory}/Contents/MacOS/ffmpeg" \
    -executable="${output_directory}/Contents/MacOS/ffprobe" \
    -always-overwrite

yt_dlp_version="$(${bundle_bin}/yt-dlp --version 2>/dev/null || printf 'unknown')"
ffmpeg_version="$(${bundle_bin}/ffmpeg -version 2>/dev/null | sed -n '1p' || printf 'unknown')"
cat > "${output_directory}/Contents/Resources/runtime-manifest.json" <<EOF
{
  "application": "ReClip",
  "configuration": "${configuration}",
  "ytDlpVersion": "${yt_dlp_version}",
  "ffmpegVersion": "${ffmpeg_version}",
  "toolLocation": "Contents/Resources/bin"
}
EOF

if [[ -n "${RECLIP_CODESIGN_IDENTITY:-}" ]]; then
    codesign --deep --force --options runtime --timestamp \
        --sign "${RECLIP_CODESIGN_IDENTITY}" "${output_directory}"
    codesign --verify --deep --strict --verbose=2 "${output_directory}"
fi

if [[ -n "${RECLIP_NOTARY_PROFILE:-}" ]]; then
    archive_path="${output_directory%.app}.zip"
    ditto -c -k --keepParent "${output_directory}" "${archive_path}"
    xcrun notarytool submit "${archive_path}" --keychain-profile "${RECLIP_NOTARY_PROFILE}" --wait
    xcrun stapler staple "${output_directory}"
fi

printf 'macOS app package created at %s\n' "${output_directory}"
