"""Encrypt persisted secrets with a per-installation master key.

The master key lives in the OS keychain when one is usable (Windows Credential
Manager, macOS Keychain, Linux Secret Service via `keyring`). Without a usable
keychain it falls back to a key file that only the current user may read.

Values are encrypted with Fernet (AES-128-CBC + HMAC-SHA256), so a modified
ciphertext is rejected instead of silently decoding into garbage.

`cryptography` is required to save secrets: if it is missing, saving is
refused with a clear message instead of silently writing a credential in
plaintext. Decrypting a stored value without it shows the field as unset.
"""

from __future__ import annotations

import base64
import copy
import os
import subprocess
import sys
import threading
from pathlib import Path
from typing import Any, Callable, Iterable, Mapping

try:  # pragma: no cover - only missing before pip installs the dependency
    from cryptography.fernet import Fernet
except ImportError:  # pragma: no cover
    Fernet = None  # type: ignore[assignment]

from .paths import CREATE_NO_WINDOW, DATA_DIR


SERVICE_NAME = "kikoeta-transl"
MASTER_KEY_NAME = "settings-master-key-v1"
KEY_FILE = DATA_DIR / ".secret.key"
BACKEND_FILE = DATA_DIR / ".secret-backend"
PREFIX = "kt-enc:v1:"

# Settings fields that must never be written to disk as plaintext.
SETTINGS_SECRET_PATHS: tuple[tuple[str, ...], ...] = (
    ("correct", "api_key"),
    ("translate", "openai", "api_key"),
    ("remote_password",),
    ("output", "lls_password"),
    ("output", "lls_key"),
)
# A checkpoint carries the same settings plus a copy of the LLS output block.
CHECKPOINT_SECRET_PATHS = SETTINGS_SECRET_PATHS
CHECKPOINT_LLS_SECRET_PATHS: tuple[tuple[str, ...], ...] = (
    ("lls_password",),
    ("lls_key",),
)

_LOCK = threading.RLock()
_FERNET: Any = None
_WARNED: set[str] = set()


class SecretStoreError(RuntimeError):
    """The master key cannot be loaded or created."""


class MasterKeyUnavailable(SecretStoreError):
    """No master key could be created yet (fresh install, no usable backend)."""


class MasterKeyMissing(SecretStoreError):
    """A master key was registered before but is no longer readable."""


def encryption_available() -> bool:
    return Fernet is not None


def encrypt_secret(value: str) -> str:
    """Encrypt a string for persistence. Empty and already-encrypted values pass through.

    Raises SecretStoreError when a master key cannot be obtained, so a caller
    never silently writes a credential to disk in plaintext.
    """
    text = str(value or "")
    if not text or text.startswith(PREFIX):
        return text
    if Fernet is None:
        raise SecretStoreError(
            "未安装 cryptography，无法加密保存凭据。"
            "请运行 python -m pip install -r requirements.txt 后重试。"
        )
    token = _get_fernet().encrypt(text.encode("utf-8")).decode("ascii")
    return PREFIX + token


def decrypt_secret(value: str) -> str:
    """Decrypt a persisted string. Plaintext values pass through for migration.

    When the master key itself is unavailable (locked keychain, missing key
    file) an empty string is returned: the stored ciphertext stays on disk and
    the UI shows the field as unset instead of exposing ciphertext as a key.
    """
    text = str(value or "")
    if not text.startswith(PREFIX):
        return text
    if Fernet is None:
        _warn(
            "无法读取已加密保存的凭据：未安装 cryptography。"
            "请运行 python -m pip install -r requirements.txt 后重新填写这些凭据。"
        )
        return ""
    try:
        fernet = _get_fernet(create=False)
        if fernet is None:
            raise MasterKeyUnavailable("凭据主密钥不可用。")
        return fernet.decrypt(text[len(PREFIX):].encode("ascii")).decode("utf-8")
    except MasterKeyMissing as exc:
        _warn(f"无法读取已保存的凭据：{exc}")
        return ""
    except SecretStoreError as exc:
        _warn(f"无法读取已保存的凭据：{exc} 请重新填写相关 API Key、密码或 LLS 凭据。")
        return ""
    except Exception as exc:
        _warn(
            "无法读取已保存的凭据"
            f"（{type(exc).__name__}）。请重新填写相关 API Key、密码或 LLS 凭据。"
        )
        return ""


def protect_mapping(
    data: Mapping[str, Any] | None,
    paths: Iterable[tuple[str, ...]],
) -> dict[str, Any]:
    """Return a deep copy with the selected string paths encrypted."""
    out = copy.deepcopy(dict(data or {}))
    for path in paths:
        _transform_path(out, path, encrypt_secret)
    return out


def unprotect_mapping(
    data: Mapping[str, Any] | None,
    paths: Iterable[tuple[str, ...]],
) -> dict[str, Any]:
    """Return a deep copy with the selected string paths decrypted."""
    out = copy.deepcopy(dict(data or {}))
    for path in paths:
        _transform_path(out, path, decrypt_secret)
    return out


def needs_encryption(
    data: Mapping[str, Any] | None,
    paths: Iterable[tuple[str, ...]],
) -> bool:
    """Whether a mapping still holds non-empty plaintext at any selected path."""
    for path in paths:
        value = _get_path(data, path)
        if isinstance(value, str) and value and not value.startswith(PREFIX):
            return True
    return False


def restrict_file_permissions(path: Path) -> None:
    """Best-effort current-user-only permissions for a secret-bearing file.

    Called on the temporary file before it replaces the destination, because
    the replacement keeps the temporary file's ACL.
    """
    target = Path(path)
    if os.name != "nt":
        try:
            target.chmod(0o600)
        except OSError:
            pass
        return
    principal = _windows_principal()
    if not principal:
        return
    try:
        subprocess.run(
            ["icacls", str(target), "/inheritance:r", "/grant:r", f"{principal}:F"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=CREATE_NO_WINDOW,
        )
    except OSError:
        pass


def cleanup_work_secrets(work_dir: Path) -> int:
    """Delete generated GalTransl configs that hold a plaintext API token.

    They are rebuilt from the (encrypted) job settings whenever a paused or
    interrupted translation restarts, so removing them at startup is safe.
    Configs without a real token are left alone to keep existing caches intact.
    """
    removed = 0
    if not work_dir.is_dir():
        return 0
    for path in work_dir.rglob("config.yaml"):
        try:
            if path.is_symlink() or not path.is_file():
                continue
            if not _config_has_token(path):
                continue
            path.unlink()
            removed += 1
        except OSError:
            continue
    return removed


def _config_has_token(path: Path) -> bool:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return False
    try:
        import yaml

        data = yaml.safe_load(text) or {}
        backend = (data.get("backendSpecific") or {}).get("OpenAI-Compatible") or {}
        for entry in backend.get("tokens") or []:
            if not isinstance(entry, dict):
                continue
            token = str(entry.get("token") or "").strip()
            if token and token != "sk-placeholder":
                return True
        return False
    except Exception:
        return "sk-placeholder" not in text and "token:" in text


def _get_fernet(create: bool = True) -> Any:
    """Return the Fernet instance, loading the master key on first use.

    With ``create=False`` a missing key returns None instead of minting a new
    one, so a read can never invalidate previously encrypted values.
    """
    global _FERNET
    with _LOCK:
        if _FERNET is None:
            key = _load_master_key(create=create)
            if key is None:
                return None
            _FERNET = Fernet(key)
        return _FERNET


def _load_master_key(*, create: bool = True) -> bytes | None:
    """Return the stored master key, creating one on first use when allowed."""
    forced = os.environ.get("KT_SECRET_BACKEND", "").strip().lower()
    if forced not in {"keyring", "file"}:
        forced = ""

    # Reuse an existing key from either backend first so ciphertext written by
    # an earlier install (or after a backend change) stays readable.
    remembered = _read_backend()
    order = [forced] if forced else (
        ["keyring", "file"] if remembered != "file" else ["file", "keyring"]
    )
    for kind in ("keyring", "file"):
        if kind not in order:
            order.append(kind)
    for kind in order:
        key = _read_key_file() if kind == "file" else _read_keyring_key()
        if key is not None:
            if kind != remembered:
                _write_backend(kind)
            return key

    if not create:
        return None

    if remembered:
        # The previously used key is gone, so the ciphertext on disk is
        # readable by nobody. Refuse to mint a replacement here: a save would
        # then overwrite every stored credential with an empty value. Say how
        # to recover, or how to start over deliberately.
        raise MasterKeyMissing(
            "原先的凭据主密钥不可用（系统密钥环或 engine/data/.secret.key）。"
            "请恢复或解锁主密钥后重试；如需重新填写所有凭据，"
            "请删除 engine/data/.secret-backend 后重启。"
        )

    if forced == "file":
        key = _create_key_file()
        _write_backend("file")
        return key
    key = _create_keyring_key()
    if key is not None:
        _write_backend("keyring")
        return key
    if forced == "keyring":
        raise MasterKeyUnavailable("KT_SECRET_BACKEND=keyring 指定的系统密钥环不可用。")
    key = _create_key_file()
    _write_backend("file")
    _warn("系统密钥环不可用，已改用本地密钥文件保存主密钥。")
    return key


def _read_backend() -> str:
    try:
        value = BACKEND_FILE.read_text(encoding="ascii").strip().lower()
    except OSError:
        return ""
    return value if value in {"keyring", "file"} else ""


def _write_backend(value: str) -> None:
    try:
        BACKEND_FILE.parent.mkdir(parents=True, exist_ok=True)
        temporary = BACKEND_FILE.with_name(BACKEND_FILE.name + ".tmp")
        temporary.write_text(value + "\n", encoding="ascii")
        os.replace(temporary, BACKEND_FILE)
        restrict_file_permissions(BACKEND_FILE)
    except OSError:
        pass


def _read_key_file() -> bytes | None:
    try:
        text = KEY_FILE.read_text(encoding="ascii").strip()
    except OSError:
        return None
    return _decode_key(text)


def _create_key_file() -> bytes:
    key = Fernet.generate_key()
    KEY_FILE.parent.mkdir(parents=True, exist_ok=True)
    try:
        descriptor = os.open(KEY_FILE, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        existing = _read_key_file()
        if existing is not None:
            return existing
        raise SecretStoreError("本地密钥文件已存在但内容无效，请检查 engine/data/.secret.key。")
    except OSError as exc:
        raise SecretStoreError(f"无法写入本地密钥文件：{exc}") from exc
    try:
        with os.fdopen(descriptor, "w", encoding="ascii") as file:
            file.write(key.decode("ascii") + "\n")
            file.flush()
            os.fsync(file.fileno())
    except Exception:
        KEY_FILE.unlink(missing_ok=True)
        raise
    finally:
        restrict_file_permissions(KEY_FILE)
    return key


def _read_keyring_key() -> bytes | None:
    keyring = _keyring()
    if keyring is None:
        return None
    try:
        stored = keyring.get_password(SERVICE_NAME, MASTER_KEY_NAME)
    except Exception:
        return None
    return _decode_key(stored) if stored else None


def _create_keyring_key() -> bytes | None:
    keyring = _keyring()
    if keyring is None or Fernet is None:
        return None
    key = Fernet.generate_key()
    try:
        keyring.set_password(SERVICE_NAME, MASTER_KEY_NAME, key.decode("ascii"))
    except Exception:
        return None
    return key


def _keyring() -> Any:
    try:
        import keyring
    except Exception:
        return None
    return keyring


def _decode_key(text: str) -> bytes | None:
    """Validate a stored Fernet key and return it in Fernet's encoded form."""
    value = str(text or "").strip()
    try:
        raw = base64.urlsafe_b64decode(value.encode("ascii"))
    except Exception:
        return None
    return value.encode("ascii") if len(raw) == 32 else None


def _get_path(data: Any, path: tuple[str, ...]) -> Any:
    current = data
    for key in path:
        if not isinstance(current, dict) or key not in current:
            return None
        current = current[key]
    return current


def _transform_path(
    data: dict[str, Any],
    path: tuple[str, ...],
    transform: Callable[[str], str],
) -> None:
    if not path:
        return
    current: Any = data
    for key in path[:-1]:
        if not isinstance(current, dict) or key not in current:
            return
        current = current[key]
    last = path[-1]
    if isinstance(current, dict) and last in current and isinstance(current[last], str):
        current[last] = transform(current[last])


def _windows_principal() -> str:
    user = os.environ.get("USERNAME") or ""
    if not user:
        return ""
    domain = os.environ.get("USERDOMAIN") or ""
    return f"{domain}\\{user}" if domain else user


def _warn(message: str) -> None:
    if message in _WARNED:
        return
    _WARNED.add(message)
    print(f"[secrets] {message}", file=sys.stderr, flush=True)