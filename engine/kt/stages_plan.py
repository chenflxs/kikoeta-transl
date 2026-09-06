from .models import FileKind, StageFlags


def planned_stages(kind: FileKind, flags: StageFlags) -> list[str]:
    stages: list[str] = []
    if kind == "media":
        stages.append("transcoding")
        if flags.enable_uvr:
            stages.append("separating")
        stages.append("asr")
    if flags.enable_correct:
        stages.append("correcting")
    if flags.enable_translate:
        stages.append("translating")
    stages.append("exporting")
    return stages
