#!/usr/bin/env python3
"""Atomically replace a planning Markdown file if its inspected hash is unchanged."""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import tempfile


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def guarded_replace(target: Path, expected_sha256: str, content: bytes) -> str:
    target = target.resolve()
    if sha256(target) != expected_sha256:
        raise RuntimeError(f"target changed since inspection: {target}")

    fd, temp_name = tempfile.mkstemp(prefix=f".{target.name}.", suffix=".tmp", dir=target.parent)
    temp = Path(temp_name)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        if sha256(target) != expected_sha256:
            raise RuntimeError(f"target changed before replacement: {target}")
        os.replace(temp, target)
        dir_fd = os.open(target.parent, os.O_RDONLY)
        try:
            os.fsync(dir_fd)
        finally:
            os.close(dir_fd)
        return sha256(target)
    finally:
        temp.unlink(missing_ok=True)


def self_test() -> None:
    from tempfile import TemporaryDirectory

    with TemporaryDirectory() as directory:
        target = Path(directory) / "sample.md"
        target.write_bytes(b"original\n")
        inspected = sha256(target)
        target.write_bytes(b"concurrent edit\n")
        try:
            guarded_replace(target, inspected, b"replacement\n")
        except RuntimeError as exc:
            assert "changed since inspection" in str(exc)
        else:
            raise AssertionError("stale hash was accepted")
        assert target.read_bytes() == b"concurrent edit\n"

        current = sha256(target)
        final = guarded_replace(target, current, b"replacement\n")
        assert target.read_bytes() == b"replacement\n"
        assert final == sha256(target)
    print("PASS: stale hash rejected without overwrite; same-directory atomic replace succeeded")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("target", nargs="?")
    parser.add_argument("expected_sha256", nargs="?")
    parser.add_argument("content_file", nargs="?")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not (args.target and args.expected_sha256 and args.content_file):
        parser.error("provide target, expected_sha256, and content_file, or use --self-test")
    target = Path(args.target)
    result = guarded_replace(target, args.expected_sha256, Path(args.content_file).read_bytes())
    print(f"PASS: atomically replaced {target}; sha256={result}")


if __name__ == "__main__":
    main()
