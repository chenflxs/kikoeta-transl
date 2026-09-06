from __future__ import annotations

from pathlib import Path

from ..models import AppSettings
from ..paths import BIN_DIR


def separate_vocals(wav_path: str | Path, work_dir: Path, settings: AppSettings) -> Path:
    try:
        import numpy as np
        import soundfile as sf
        from .uvr_infer import Predictor
    except ImportError as exc:
        raise RuntimeError("人声分离需要安装 soundfile / librosa / numpy / onnxruntime") from exc

    model_name = settings.uvr_model
    if not model_name:
        models = sorted((BIN_DIR / "separate").glob("*.onnx"))
        if not models:
            raise FileNotFoundError("未找到 UVR ONNX 模型，请放到 bin/separate")
        model_name = models[0].name
    model_path = Path(model_name)
    if not model_path.is_file():
        model_path = BIN_DIR / "separate" / model_name
    if not model_path.is_file():
        raise FileNotFoundError(f"未找到 UVR 模型: {model_path}")

    args = {
        "model_path": str(model_path),
        "denoise": True,
        "margin": 44100,
        "chunks": 15,
        "n_fft": 6144,
        "dim_t": 8,
        "dim_f": 2048,
    }
    predictor = Predictor(args)
    vocals, _no_vocals, sampling_rate = predictor.predict(str(wav_path))
    work_dir.mkdir(parents=True, exist_ok=True)
    output = work_dir / f"{Path(wav_path).stem}.vocals.wav"
    sf.write(str(output), vocals, sampling_rate)
    return output
