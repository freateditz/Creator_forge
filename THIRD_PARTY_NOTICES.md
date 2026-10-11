# Third-Party Notices — CreatorForge

This document lists third-party software used by CreatorForge and their licenses.

---

## AI Source Separation

### demucs (Python package)
- **Version**: 4.1.0
- **Author**: Meta Research (Facebook)
- **License**: MIT License
- **URL**: https://github.com/facebookresearch/demucs
- **Usage**: Audio source separation backend

### htdemucs (model weights)
- **Version**: Bundled with demucs 4.1.0
- **Author**: Meta Research (Facebook)
- **License**: Creative Commons Attribution Non-Commercial 4.0 International
  (CC BY-NC 4.0)
- **URL**: https://huggingface.co/facebook/htdemucs
- **Usage**: Pre-trained hybrid transformer model for 4-stem source separation
  (vocals, drums, bass, other)
- **IMPORTANT**: The htdemucs model weights may only be used for
  **non-commercial purposes**. By installing and using the AI Vocal Separator
  feature, you agree to use it for non-commercial purposes only.

### PyTorch
- **Version**: 2.x (installed as a dependency of demucs)
- **License**: BSD-style (see https://github.com/pytorch/pytorch/blob/main/LICENSE)
- **URL**: https://pytorch.org

### torchaudio
- **Version**: 2.x (installed as a dependency of demucs)
- **License**: BSD-style (see https://github.com/pytorch/audio/blob/main/LICENSE)
- **URL**: https://pytorch.org/audio

---

## AI Background Removal

### rembg (Python package)
- **Version**: 2.0.85
- **Author**: Daniel Gatis
- **License**: MIT License
- **URL**: https://github.com/danielgatis/rembg
- **Usage**: Background removal inference backend; wraps ONNX Runtime
  and manages model downloads

### isnet-general-use (model weights)
- **Version**: Distributed via rembg 2.0.85
- **Author**: Xuebin Qin et al. (Dichotomous Image Segmentation)
- **Code license**: Apache 2.0 (original repo: xuebinqin/DIS)
- **Model weights**: Available for personal and commercial use;
  distributed through the rembg project
- **URL**: https://github.com/xuebinqin/DIS
- **Usage**: High-quality foreground segmentation model (~177 MB ONNX);
  used for transparent PNG generation
- **Note**: End users are responsible for verifying that their specific
  deployment complies with applicable licenses.

### ONNX Runtime
- **Version**: 1.31.x (installed as a dependency of rembg[cpu])
- **License**: MIT License
- **URL**: https://onnxruntime.ai

### Pillow (PIL Fork)
- **Version**: 12.x (installed as a dependency of rembg)
- **License**: HPND License (Historical Permission Notice and Disclaimer)
- **URL**: https://python-pillow.org
- **Usage**: Image loading, EXIF orientation handling, and PNG export

### NumPy
- **Version**: 2.x (installed as a dependency of rembg)
- **License**: BSD 3-Clause License
- **URL**: https://numpy.org

### SciPy
- **Version**: 1.x (installed as a dependency of pymatting/rembg)
- **License**: BSD 3-Clause License
- **URL**: https://scipy.org

### pymatting
- **Version**: 1.x (installed as a dependency of rembg)
- **License**: MIT License
- **URL**: https://github.com/99991/pymatting
- **Usage**: Optional alpha matting for improved fine-edge quality

---

## Media Processing

### FFmpeg
- **License**: GNU LGPL v2.1+ (some optional components: GPL)
- **URL**: https://ffmpeg.org
- **Usage**: Audio extraction from video files, media probing

### yt-dlp
- **License**: The Unlicense (public domain)
- **URL**: https://github.com/yt-dlp/yt-dlp
- **Usage**: Video/audio download engine

---

## Browser Extension (build-time only)

The browser extension uses build and test tools that are **not bundled** in
the distributed extension or application. They are only required when building
the extension from source.

### esbuild
- **Version**: 0.24.x
- **License**: MIT License
- **URL**: https://esbuild.github.io
- **Usage**: TypeScript/JavaScript bundler for the browser extension

### TypeScript
- **Version**: 5.x
- **License**: Apache 2.0
- **URL**: https://www.typescriptlang.org
- **Usage**: Type-checked source language for the browser extension

### Vitest
- **Version**: 2.x
- **License**: MIT License
- **URL**: https://vitest.dev
- **Usage**: Test runner for browser extension unit tests (dev only)

### jsdom
- **Version**: 25.x
- **License**: MIT License
- **URL**: https://github.com/jsdom/jsdom
- **Usage**: DOM environment for extension unit tests (dev only)

---

## Flutter Packages

For Flutter package licenses, run:
```
flutter pub deps
```
or view licences in-app via the `LicensePage` widget.
