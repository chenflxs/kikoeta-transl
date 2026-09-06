from pathlib import Path

ENGINE_DIR = Path(__file__).resolve().parent.parent
ROOT_DIR = ENGINE_DIR.parent
GALTRANSL_ROOT = ENGINE_DIR / "GalTransl"
BIN_DIR = ROOT_DIR / "bin"
WORK_DIR = ENGINE_DIR / "work"
DATA_DIR = ENGINE_DIR / "data"
OUTPUT_DIR = ROOT_DIR / "output"

SUBTITLE_EXTS = {".srt", ".lrc", ".vtt", ".ass", ".ssa"}
MEDIA_EXTS = {
    ".mp3", ".wav", ".flac", ".m4a", ".aac", ".ogg", ".opus", ".wma", ".aiff",
    ".mp4", ".mkv", ".webm", ".avi", ".mov", ".wmv", ".m4v", ".ts", ".flv",
}

CREATE_NO_WINDOW = 0x08000000
