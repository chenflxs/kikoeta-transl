from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from threading import Event

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from kt.models import StageFlags
from kt.pipeline import process_file
from kt.settings import load_settings
from kt.paths import WORK_DIR


def main() -> None:
    parser = argparse.ArgumentParser(prog="kt")
    sub = parser.add_subparsers(dest="cmd", required=True)
    serve = sub.add_parser("serve", help="启动本地 engine")
    serve.add_argument("--host", default="127.0.0.1")
    serve.add_argument("--port", type=int, default=18765)
    run = sub.add_parser("run", help="处理本地文件")
    run.add_argument("files", nargs="+")
    run.add_argument("--uvr", action="store_true")
    run.add_argument("--correct", action="store_true")
    run.add_argument("--no-translate", action="store_true")
    args = parser.parse_args()
    if args.cmd == "serve":
        import server as engine_server
        sys.argv = ["server.py", "--host", args.host, "--port", str(args.port)]
        engine_server.main()
        return
    settings = load_settings()
    flags = StageFlags(
        enable_uvr=args.uvr,
        enable_correct=args.correct,
        enable_translate=not args.no_translate,
    )
    job_dir = WORK_DIR / "cli"
    job_dir.mkdir(parents=True, exist_ok=True)
    for path in args.files:
        result = process_file(
            path=path,
            settings=settings,
            flags=flags,
            job_dir=job_dir / Path(path).stem,
            emit=lambda event_type, **payload: print(event_type, payload, flush=True),
            stop_event=Event(),
        )
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
