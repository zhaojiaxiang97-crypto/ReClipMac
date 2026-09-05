#!/usr/bin/env bash

set -euo pipefail

configuration="${1:-Release}"
script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/../.." && pwd)"
build_directory="${RECLIP_BUILD_DIR:-${repository_root}/.build/package-linux-${configuration}}"
appdir="${RECLIP_APPDIR:-${repository_root}/.artifacts/linux/ReClip-${configuration}.AppDir}"
output_image="${RECLIP_OUTPUT_IMAGE:-${repository_root}/.artifacts/linux/ReClip-${configuration}-x86_64.AppImage}"
qt_root="${RECLIP_QT_ROOT:-}"
tool_bin="${RECLIP_TOOL_BIN:-}"
linuxdeployqt="${RECLIP_LINUXDEPLOYQT:-}"

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

if [[ -z "${linuxdeployqt}" ]]; then
    linuxdeployqt="$(command -v linuxdeployqt || true)"
fi
[[ -x "${linuxdeployqt}" ]] || die "找不到 linuxdeployqt，请设置 RECLIP_LINUXDEPLOYQT"

if [[ -n "${qt_root}" ]]; then
    qt_cmake="${qt_root}/bin/qt-cmake"
else
    qt_cmake="$(command -v qt-cmake || true)"
fi
[[ -x "${qt_cmake}" ]] || die "找不到 qt-cmake，请设置 RECLIP_QT_ROOT"

[[ ! -e "${appdir}" ]] || die "AppDir 已存在，拒绝覆盖：${appdir}"
[[ ! -e "${output_image}" ]] || die "AppImage 已存在，拒绝覆盖：${output_image}"

yt_dlp="$(resolve_tool yt-dlp)"
ffmpeg="$(resolve_tool ffmpeg)"
ffprobe="$(resolve_tool ffprobe)"

"${qt_cmake}" -S "${repository_root}" -B "${build_directory}" -DCMAKE_BUILD_TYPE="${configuration}" -DBUILD_TESTING=OFF
cmake --build "${build_directory}" --config "${configuration}" --parallel

source_binary="${build_directory}/ReClip"
if [[ ! -x "${source_binary}" ]]; then
    source_binary="${build_directory}/${configuration}/ReClip"
fi
[[ -x "${source_binary}" ]] || die "构建完成但没有找到 ReClip 可执行文件"

mkdir -p "${appdir}/usr/bin" "${appdir}/usr/share/applications" "${appdir}/usr/share/metainfo"
icon_source="${repository_root}/packaging/linux/ReClip.svg"
[[ -f "${icon_source}" ]] || die "找不到 Linux 应用图标：${icon_source}"
mkdir -p "${appdir}/usr/share/icons/hicolor/scalable/apps"
cp "${source_binary}" "${appdir}/usr/bin/ReClip"
cp -L "${yt_dlp}" "${appdir}/usr/bin/yt-dlp"
cp -L "${ffmpeg}" "${appdir}/usr/bin/ffmpeg"
cp -L "${ffprobe}" "${appdir}/usr/bin/ffprobe"
cp "${icon_source}" "${appdir}/ReClip.svg"
cp "${icon_source}" "${appdir}/usr/share/icons/hicolor/scalable/apps/ReClip.svg"
chmod 755 "${appdir}/usr/bin/ReClip" "${appdir}/usr/bin/yt-dlp" "${appdir}/usr/bin/ffmpeg" "${appdir}/usr/bin/ffprobe"

cat > "${appdir}/ReClip.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=ReClip
Comment=Cross-platform media downloader
Exec=ReClip
Icon=ReClip
Terminal=false
Categories=AudioVideo;Network;
EOF
cp "${appdir}/ReClip.desktop" "${appdir}/usr/share/applications/ReClip.desktop"

license_directory="${appdir}/usr/share/doc/reclip/licenses"
mkdir -p "${license_directory}"
cp "${repository_root}/LICENSE" "${license_directory}/LICENSE"
cp "${repository_root}/NOTICE" "${license_directory}/NOTICE"
cp "${repository_root}/packaging/linux/THIRD_PARTY_NOTICES.md" "${appdir}/usr/share/doc/reclip/THIRD_PARTY_NOTICES.md"

ffmpeg_license="$(find "$(dirname -- "${ffmpeg}")" -maxdepth 2 -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' \) -print -quit 2>/dev/null || true)"
if [[ -n "${ffmpeg_license}" ]]; then
    cp "${ffmpeg_license}" "${license_directory}/FFmpeg-LICENSE"
else
    printf '保留 FFmpeg 构建目录中的许可证文件；发布前请核对实际构建的 LGPL/GPL 配置。\n' > "${license_directory}/FFmpeg-LICENSE-LOCATION.txt"
fi

pushd "$(dirname -- "${appdir}")" >/dev/null
"${linuxdeployqt}" "${appdir}/usr/bin/ReClip" \
    -qmldir="${repository_root}/qml" \
    -executable="${appdir}/usr/bin/ffmpeg" \
    -executable="${appdir}/usr/bin/ffprobe" \
    -appimage
popd >/dev/null

generated_image="$(find "$(dirname -- "${appdir}")" -maxdepth 1 -type f -name '*.AppImage' -print -quit 2>/dev/null || true)"
[[ -n "${generated_image}" ]] || die "linuxdeployqt 没有生成 AppImage"
mkdir -p "$(dirname -- "${output_image}")"
mv "${generated_image}" "${output_image}"
chmod 755 "${output_image}"

printf 'Linux AppImage created at %s\n' "${output_image}"
