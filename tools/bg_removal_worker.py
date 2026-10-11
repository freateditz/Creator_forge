#!/usr/bin/env python3
"""
CreatorForge Background Removal Worker v1.0

Reads one JSON command from stdin and emits JSON progress lines to stdout.

Actions:
  check_runtime       — report installed library versions and model cache status.
  download_model      — pre-download model weights.
  remove_background   — run inference and write a transparent PNG.

License: rembg — MIT License.
IS-Net / isnet-general-use weights — Apache 2.0 (commercially usable).
ONNX Runtime — MIT License.
Pillow — HPND License.
"""
import sys
import json
import os
import traceback


def emit(msg: dict) -> None:
    print(json.dumps(msg, ensure_ascii=False), flush=True)


def main() -> None:
    try:
        raw = sys.stdin.readline()
        if not raw or not raw.strip():
            emit({"type": "error", "message": "No command received on stdin"})
            sys.exit(1)
        cmd = json.loads(raw)
    except json.JSONDecodeError as exc:
        emit({"type": "error", "message": f"Invalid JSON on stdin: {exc}"})
        sys.exit(1)

    action = cmd.get("action", "")
    try:
        if action == "check_runtime":
            _handle_check_runtime(cmd)
        elif action == "download_model":
            _handle_download_model(cmd)
        elif action == "remove_background":
            _handle_remove_background(cmd)
        else:
            emit({"type": "error", "message": f"Unknown action: {action!r}"})
            sys.exit(1)
    except SystemExit:
        raise
    except Exception as exc:
        emit({
            "type": "error",
            "message": str(exc),
            "traceback": traceback.format_exc(),
        })
        sys.exit(1)


# ---------------------------------------------------------------------------
# Action handlers
# ---------------------------------------------------------------------------

def _handle_check_runtime(cmd: dict) -> None:
    model_name: str = cmd.get("model_name", "isnet-general-use")
    try:
        import rembg
        import onnxruntime as ort
    except ImportError as exc:
        emit({"type": "error", "message": f"Runtime not ready: {exc}"})
        sys.exit(1)

    rembg_home = os.environ.get("U2NET_HOME", "")
    model_cached = _is_model_cached(model_name, rembg_home)
    providers = ort.get_available_providers()

    emit({
        "type": "runtime_info",
        "rembg_version": getattr(rembg, "__version__", "unknown"),
        "ort_version": ort.__version__,
        "model_name": model_name,
        "model_cached": model_cached,
        "providers": providers,
    })


def _handle_download_model(cmd: dict) -> None:
    model_name: str = cmd.get("model_name", "isnet-general-use")
    emit({"type": "stage", "stage": "downloading_model", "model": model_name})
    try:
        import rembg
        # new_session triggers model download if not cached
        rembg.new_session(model_name)
        rembg_home = os.environ.get("U2NET_HOME", "")
        model_cached = _is_model_cached(model_name, rembg_home)
        emit({"type": "complete", "model": model_name, "cached": model_cached})
    except Exception as exc:
        emit({"type": "error", "message": f"Model download failed: {exc}"})
        sys.exit(1)


def _handle_remove_background(cmd: dict) -> None:  # noqa: C901
    from pathlib import Path
    import shutil
    import io

    input_path: str = cmd.get("input_path", "")
    output_path: str = cmd.get("output_path", "")
    model_name: str = cmd.get("model_name", "isnet-general-use")
    alpha_matting: bool = bool(cmd.get("alpha_matting", False))
    alpha_matting_fg: int = int(cmd.get("alpha_matting_fg_threshold", 240))
    alpha_matting_bg: int = int(cmd.get("alpha_matting_bg_threshold", 10))
    alpha_matting_erode: int = int(cmd.get("alpha_matting_erode_size", 10))
    post_process: bool = bool(cmd.get("post_process_mask", False))

    if not input_path or not os.path.isfile(input_path):
        emit({"type": "error", "message": f"Input file not found: {input_path!r}"})
        sys.exit(1)
    if not output_path:
        emit({"type": "error", "message": "No output_path specified"})
        sys.exit(1)

    from PIL import Image, ImageOps

    # 1. Analyze image
    emit({"type": "stage", "stage": "analyzing_image"})
    try:
        with Image.open(input_path) as raw:
            raw.load()
            # Apply EXIF orientation so mask aligns with visual orientation
            oriented = ImageOps.exif_transpose(raw)
            orig_width, orig_height = oriented.size
            orig_mode = oriented.mode
            has_existing_alpha = orig_mode in ("RGBA", "LA", "PA")

            # rembg works best with RGB
            rgb_img = oriented.convert("RGB")
            # Encode as PNG bytes for rembg (removes EXIF, forces RGB)
            buf = io.BytesIO()
            rgb_img.save(buf, format="PNG")
            input_bytes = buf.getvalue()
    except Exception as exc:
        emit({"type": "error", "message": f"Cannot open image: {exc}"})
        sys.exit(1)

    emit({
        "type": "image_info",
        "width": orig_width,
        "height": orig_height,
        "mode": orig_mode,
        "has_existing_alpha": has_existing_alpha,
    })

    if max(orig_width, orig_height) > 4000:
        emit({
            "type": "info",
            "message": (
                f"Large image ({orig_width}×{orig_height}); "
                "inference may take several minutes."
            ),
        })

    # 2. Load model
    emit({"type": "stage", "stage": "loading_model", "model": model_name})
    import rembg
    try:
        session = rembg.new_session(model_name)
    except Exception as exc:
        emit({"type": "error", "message": f"Model load failed: {exc}"})
        sys.exit(1)

    # 3. Run inference (blocking; no mid-inference progress from rembg)
    emit({"type": "stage", "stage": "generating_mask"})
    try:
        output_bytes = rembg.remove(
            input_bytes,
            session=session,
            alpha_matting=alpha_matting,
            alpha_matting_foreground_threshold=alpha_matting_fg,
            alpha_matting_background_threshold=alpha_matting_bg,
            alpha_matting_erode_size=alpha_matting_erode,
            post_process_mask=post_process,
        )
    except Exception as exc:
        emit({"type": "error", "message": f"Inference failed: {exc}"})
        sys.exit(1)

    # 4. Decode and validate result
    emit({"type": "stage", "stage": "refining_edges"})
    try:
        result_img = Image.open(io.BytesIO(output_bytes))
        result_img.load()
    except Exception as exc:
        emit({"type": "error", "message": f"Result decode failed: {exc}"})
        sys.exit(1)

    if result_img.mode != "RGBA":
        result_img = result_img.convert("RGBA")

    # Ensure dimensions match original (rembg should preserve them)
    if result_img.size != (orig_width, orig_height):
        emit({
            "type": "info",
            "message": (
                f"Resizing result {result_img.size} → "
                f"({orig_width}, {orig_height})"
            ),
        })
        result_img = result_img.resize((orig_width, orig_height), Image.LANCZOS)

    # 5. Export to PNG with atomic write (temp → rename)
    emit({"type": "stage", "stage": "exporting"})
    out_path = Path(output_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = str(out_path) + ".tmp"
    try:
        result_img.save(tmp_path, format="PNG", optimize=False)
        result_img.close()
        if os.path.exists(output_path):
            os.remove(output_path)
        shutil.move(tmp_path, output_path)
    except Exception as exc:
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass
        emit({"type": "error", "message": f"Export failed: {exc}"})
        sys.exit(1)

    # 6. Verify saved file
    emit({"type": "stage", "stage": "verifying"})
    if not os.path.isfile(output_path):
        emit({"type": "error", "message": f"Output missing: {output_path!r}"})
        sys.exit(1)
    out_size = os.path.getsize(output_path)
    if out_size == 0:
        emit({"type": "error", "message": "Output file is empty"})
        sys.exit(1)

    try:
        with Image.open(output_path) as verify_img:
            verify_img.load()
            has_alpha = verify_img.mode == "RGBA"
            out_w, out_h = verify_img.size
    except Exception as exc:
        emit({"type": "error", "message": f"Output verification failed: {exc}"})
        sys.exit(1)

    emit({
        "type": "complete",
        "output_path": output_path,
        "width": out_w,
        "height": out_h,
        "has_alpha": has_alpha,
        "file_size": out_size,
    })


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _is_model_cached(model_name: str, rembg_home: str) -> bool:
    """Check if the ONNX model file exists in the rembg model cache directory."""
    if not rembg_home:
        home = os.path.join(os.path.expanduser("~"), ".u2net")
    else:
        home = rembg_home
    # rembg 2.0.x stores models at: $U2NET_HOME/models/{name}/{name}.onnx
    model_path = os.path.join(home, "models", model_name, f"{model_name}.onnx")
    return os.path.isfile(model_path)


if __name__ == "__main__":
    main()
