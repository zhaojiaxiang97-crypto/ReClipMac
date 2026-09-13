"""Pinned, in-process yt-dlp adapter. No CLI, config files or external tools.

Metadata inspection and a deliberately narrow native downloader are exposed.
The native downloader accepts only one resolved format; the host owns multi-
format merging and FFmpeg post-processing.
"""

import json
from pathlib import Path
import re
import sys
import time


def _deny_external_process(event, args):
    if event in {"subprocess.Popen", "os.system", "os.posix_spawn", "os.exec", "os.fork", "os.forkpty", "os.spawn"}:
        raise RuntimeError("external-process-disabled: 内嵌解析器不允许启动外部程序")


# This runtime is dedicated to ReClip. An audit hook is a defence-in-depth
# check, not an OS sandbox or proof about native extensions.
sys.addaudithook(_deny_external_process)

import yt_dlp
from yt_dlp.globals import plugin_dirs
from yt_dlp.version import __version__ as yt_dlp_version

# Pinned upstream API: do not discover Python code in user plugin directories.
plugin_dirs.value = []


class Cancelled(Exception):
    pass


def _safe_error(error):
    return re.sub(r"https?://[^\s\"'<>]+", "<URL>", str(error))[:1600]


def run(request_json, is_cancelled):
    """Return a JSON envelope; cancellation is acknowledged after unwinding."""
    request = json.loads(request_json)
    timeout = max(0.1, min(float(request.get("timeout", 30)), 60))
    deadline = time.monotonic() + timeout

    def checkpoint():
        if is_cancelled():
            raise Cancelled()
        if time.monotonic() >= deadline:
            raise TimeoutError("解析超时，请检查网络后重试")

    class Logger:
        def debug(self, message):
            checkpoint()

        info = debug
        warning = debug
        error = debug

    class Resolver(yt_dlp.YoutubeDL):
        def urlopen(self, request):
            checkpoint()
            response = super().urlopen(request)
            try:
                checkpoint()
            except BaseException:
                response.close()
                raise
            return response

    try:
        checkpoint()
        operation = request.get("operation")
        if operation == "probe":
            result = {
                "python": sys.version.split()[0],
                "ytDlp": yt_dlp_version,
                "backend": "embedded-python",
                "externalProcesses": False,
                "javascript": False,
                "isolated": bool(sys.flags.isolated),
            }
        else:
            options = {
                "quiet": True,
                "no_warnings": True,
                "noplaylist": True,
                "skip_download": operation != "download",
                "cachedir": False,
                "socket_timeout": min(timeout, 5),
                "retries": 0,
                "extractor_retries": 0,
                "js_runtimes": {},
                "remote_components": set(),
                "logger": Logger(),
                "progress_hooks": [lambda progress: checkpoint()],
                "postprocessors": [],
                "fixup": "never",
                # Avoid yt-dlp's default-format FFmpeg availability probe.
                "format": "best" if operation == "download" else "bestvideo*+bestaudio/best",
            }
            selector = request.get("format")
            if selector:
                options["format"] = selector
            if operation == "download":
                output_path = str(request.get("outputPath") or "").strip()
                if not output_path:
                    raise ValueError("native download requires outputPath")
                options.update({
                    "outtmpl": output_path,
                    "overwrites": False,
                    "external_downloader": "native",
                })
            headers = request.get("httpHeaders")
            if isinstance(headers, dict):
                options["http_headers"] = {
                    str(name): str(value)
                    for name, value in headers.items()
                    if str(name).strip() and str(value).strip()
                }
            with Resolver(options) as downloader:
                info = downloader.extract_info(request["url"], download=False)
                checkpoint()
                if not info or info.get("_type") in {"playlist", "multi_video"}:
                    raise ValueError("暂不支持播放列表或空媒体结果")
                if operation == "download":
                    if info.get("has_drm"):
                        raise ValueError("native download does not support DRM media")
                    if info.get("requested_formats"):
                        raise ValueError("native download only supports one resolved format; use the FFmpeg SDK merger")
                    downloader.process_info(info)
                    checkpoint()
                    output = Path(output_path)
                    if not output.is_file():
                        raise ValueError("yt-dlp completed without producing the requested output file")
                    result = {
                        "path": str(output.resolve()),
                        "bytes": output.stat().st_size,
                        "ext": info.get("ext"),
                        "format": info.get("format_id"),
                        "protocol": info.get("protocol"),
                    }
                else:
                    result = downloader.sanitize_info(info)
        checkpoint()
        return json.dumps({"ok": True, "payload": result}, ensure_ascii=False)
    except Cancelled:
        return json.dumps({"ok": False, "code": "cancelled", "error": "已取消"})
    except Exception as error:
        if is_cancelled():
            code, message = "cancelled", "已取消"
        elif isinstance(error, TimeoutError) or time.monotonic() >= deadline:
            code, message = "timeout", "解析超时，请检查网络后重试"
        else:
            code, message = "tool-error", _safe_error(error)
        return json.dumps({"ok": False, "code": code, "error": message}, ensure_ascii=False)
