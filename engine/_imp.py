import sys, time
from pathlib import Path
sys.path.insert(0, str(Path('.').resolve()))
print('1', flush=True)
from kt.models import Cue, StageFlags
print('2', flush=True)
from kt.subtitle import parse_subtitle_text
print('3', flush=True)
from kt.stages.export import export_cues
print('4', flush=True)
from kt.stages_plan import planned_stages
print('5', flush=True)
from kt.pipeline import detect_kind
print('6', flush=True)
print('ok', detect_kind('a.mp3'), flush=True)
