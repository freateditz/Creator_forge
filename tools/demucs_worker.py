#!/usr/bin/env python3
"""
CreatorForge Demucs Worker v1.0
Performs AI-powered source separation using the htdemucs model.

This script is managed by CreatorForge and reads one JSON command from stdin,
then emits JSON progress lines to stdout before exiting.

License: Demucs package — MIT License.
htdemucs model weights — CC BY-NC 4.0 (non-commercial use only).
PyTorch — BSD-style license.
"""
import sys
import json
import os
import traceback

# Must be first import so patch is in effect before demucs is ever imported.
import tqdm as _tqdm_mod
from tqdm import auto as _tqdm_auto


def emit(msg: dict) -> None:
    print(json.dumps(msg, ensure_ascii=False), flush=True)


# ---------------------------------------------------------------------------
# tqdm patch — must happen before any demucs import so the tqdm binding
# inside demucs.apply picks up this subclass at import time.
# ---------------------------------------------------------------------------
class _JsonTqdm(_tqdm_mod.tqdm):
    """tqdm subclass that emits JSON progress events instead of printing.

    Also exposes itself as `_JsonTqdm.tqdm` so that call sites that do
    `from tqdm import tqdm; tqdm.tqdm(...)` (treating the imported name
    as a module) continue to work.
    """

    def update(self, n: int = 1):
        result = super().update(n)
        if self.total and self.total > 0:
            pct = round(100.0 * self.n / self.total, 1)
            emit({"type": "progress", "stage": "separating", "percent": pct})
        return result

    def close(self):
        super().close()


# Let `_JsonTqdm.tqdm` point back to itself so that call sites that do
# `tqdm.tqdm(...)` (where `tqdm` was bound via `from tqdm import tqdm`)
# still find a valid callable.
_JsonTqdm.tqdm = _JsonTqdm  # type: ignore[attr-defined]

_tqdm_mod.tqdm = _JsonTqdm  # type: ignore[assignment]
_tqdm_auto.tqdm = _JsonTqdm  # type: ignore[assignment]


# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------

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
            _handle_check_runtime()
        elif action == "download_model":
            _handle_download_model(cmd)
        elif action == "separate":
            _handle_separate(cmd)
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

def _handle_check_runtime() -> None:
    """Report installed library versions and available hardware accelerators."""
    try:
        import torch
        import demucs
    except ImportError as exc:
        emit({"type": "error", "message": f"Runtime not ready: {exc}"})
        sys.exit(1)

    mps_ok = bool(
        getattr(torch.backends, "mps", None)
        and torch.backends.mps.is_available()
    )
    cuda_ok = bool(torch.cuda.is_available())
    emit({
        "type": "runtime_info",
        "demucs_version": getattr(demucs, "__version__", "unknown"),
        "torch_version": torch.__version__,
        "mps_available": mps_ok,
        "cuda_available": cuda_ok,
        "cuda_device_count": torch.cuda.device_count() if cuda_ok else 0,
    })


def _handle_download_model(cmd: dict) -> None:
    """Pre-download model weights into the torch hub cache."""
    model_name: str = cmd.get("model_name", "htdemucs")
    emit({"type": "stage", "stage": "downloading_model", "model": model_name})
    try:
        from demucs.pretrained import get_model
        get_model(model_name)
        emit({"type": "complete", "model": model_name})
    except Exception as exc:
        emit({"type": "error", "message": f"Model download failed: {exc}"})
        sys.exit(1)


def _handle_separate(cmd: dict) -> None:  # noqa: C901 (acceptable complexity)
    """Run inference and write stem WAV files."""
    from pathlib import Path

    input_path: str = cmd.get("input_path", "")
    output_dir: str = cmd.get("output_dir", "")
    model_name: str = cmd.get("model_name", "htdemucs")
    device_pref: str = cmd.get("device", "auto")
    two_stems: bool = bool(cmd.get("two_stems", True))
    raw_name: str = cmd.get("track_name") or Path(input_path).stem

    # --- Validate inputs ------------------------------------------------
    if not input_path or not os.path.isfile(input_path):
        emit({"type": "error", "message": f"Input file not found: {input_path!r}"})
        sys.exit(1)
    if not output_dir:
        emit({"type": "error", "message": "No output_dir specified"})
        sys.exit(1)

    # --- Imports happen after tqdm patch --------------------------------
    import torch
    import torchaudio

    # Patch demucs.apply *before* importing it so its module-level `tqdm`
    # binding sees our subclass.
    import demucs.apply as _apply_mod
    _apply_mod.tqdm = _JsonTqdm  # type: ignore[assignment]

    from demucs.pretrained import get_model
    from demucs.apply import apply_model

    device = _resolve_device(device_pref)
    emit({"type": "stage", "stage": "loading_model", "model": model_name, "device": device})

    model = get_model(model_name)
    model.eval()
    model = model.to(device)

    # --- Load and condition audio ----------------------------------------
    emit({"type": "stage", "stage": "preparing_audio"})

    wav, sr = torchaudio.load(input_path)

    if sr != model.samplerate:
        emit({"type": "info", "message": f"Resampling {sr} → {model.samplerate} Hz"})
        wav = torchaudio.functional.resample(wav, sr, model.samplerate)

    # Ensure exactly stereo
    if wav.shape[0] == 1:
        wav = wav.repeat(2, 1)
    elif wav.shape[0] > 2:
        wav = wav[:2]

    # --- Inference -------------------------------------------------------
    emit({"type": "stage", "stage": "separating"})

    with torch.no_grad():
        # apply_model expects [batch, channels, time]; returns [batch, stems, channels, time]
        sources = apply_model(
            model,
            wav[None].to(device),
            device=device,
            progress=True,
            num_workers=0,
        )

    sources = sources[0]  # [n_stems, channels, time]
    stem_names: list = model.sources  # e.g. ['drums', 'bass', 'other', 'vocals']

    if "vocals" not in stem_names:
        emit({"type": "error", "message": f"Model has no 'vocals' stem; got {stem_names}"})
        sys.exit(1)

    # --- Export stems ----------------------------------------------------
    emit({"type": "stage", "stage": "exporting_stems"})

    out_path = Path(output_dir)
    out_path.mkdir(parents=True, exist_ok=True)

    # Sanitise track name: keep printable ASCII, collapse path separators.
    safe_name = "".join(
        c if c.isprintable() and c not in r'/\:*?"<>|' else "_"
        for c in raw_name
    )[:200]

    sample_rate: int = model.samplerate
    results: dict[str, str] = {}

    if two_stems:
        vocals_idx = stem_names.index("vocals")
        vocals_t = sources[vocals_idx].cpu()
        instr_t = sum(
            sources[i] for i, n in enumerate(stem_names) if n != "vocals"
        ).cpu()

        vocals_path = str(out_path / f"{safe_name} - Vocals.wav")
        instr_path = str(out_path / f"{safe_name} - Instrumental.wav")

        torchaudio.save(vocals_path, vocals_t, sample_rate, bits_per_sample=16)
        torchaudio.save(instr_path, instr_t, sample_rate, bits_per_sample=16)

        results["vocals"] = vocals_path
        results["instrumental"] = instr_path
    else:
        # Individual stems
        for idx, name in enumerate(stem_names):
            stem_path = str(out_path / f"{safe_name} - {name.capitalize()}.wav")
            torchaudio.save(
                stem_path, sources[idx].cpu(), sample_rate, bits_per_sample=16
            )
            results[name] = stem_path

        # Also produce an instrumental mix (all non-vocal stems summed)
        instr_t = sum(
            sources[i] for i, n in enumerate(stem_names) if n != "vocals"
        ).cpu()
        instr_path = str(out_path / f"{safe_name} - Instrumental.wav")
        torchaudio.save(instr_path, instr_t, sample_rate, bits_per_sample=16)
        results["instrumental"] = instr_path

    # --- Verify ----------------------------------------------------------
    emit({"type": "stage", "stage": "verifying"})

    for stem_key, path in results.items():
        if not os.path.isfile(path):
            emit({"type": "error", "message": f"Output missing for stem '{stem_key}': {path!r}"})
            sys.exit(1)
        if os.path.getsize(path) == 0:
            emit({"type": "error", "message": f"Output empty for stem '{stem_key}': {path!r}"})
            sys.exit(1)

    emit({"type": "complete", "stems": results})


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _resolve_device(pref: str) -> str:
    import torch

    if pref == "cpu":
        return "cpu"
    if pref == "mps":
        if getattr(torch.backends, "mps", None) and torch.backends.mps.is_available():
            return "mps"
        return "cpu"
    if pref == "cuda":
        return "cuda" if torch.cuda.is_available() else "cpu"
    # auto
    if getattr(torch.backends, "mps", None) and torch.backends.mps.is_available():
        return "mps"
    if torch.cuda.is_available():
        return "cuda"
    return "cpu"


if __name__ == "__main__":
    main()
