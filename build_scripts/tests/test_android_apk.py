import asyncio
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from app.android import AndroidBuilder
from app.builder import Builder
from app.flutter import build


class BuildScriptsExtraTest(unittest.TestCase):
    def test_android_apk_only_splits_abis_and_enables_native_compression(self):
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp)
            root = workspace / "OneXray"
            root.mkdir()
            (root / "pubspec.yaml").write_bytes(b"name: onexray\nversion: 26.8.5+1\n")
            calls = []

            def command(args, **kwargs):
                calls.append((args, kwargs))
                out_dir = root / "build/app/outputs/flutter-apk"
                out_dir.mkdir(parents=True, exist_ok=True)
                for abi in ("arm64-v8a", "x86_64"):
                    (out_dir / f"app-{abi}-release.apk").write_bytes(abi.encode())

            with (
                mock.patch.dict(
                    os.environ,
                    {"BUILD_NUMBER": "1", "ONEXRAY_ANDROID_APK_ONLY": "1"},
                ),
                mock.patch.object(Builder, "build_core"),
                mock.patch("app.flutter.run_command", side_effect=command),
                mock.patch("app.android.run_command", side_effect=command),
            ):
                build("OneXray", "android", str(root / "build_scripts"))

            apk_call = [c for c in calls if "apk" in c[0]][0]
            self.assertIn("--split-per-abi", apk_call[0])
            self.assertIn("--obfuscate", apk_call[0])
            self.assertEqual(
                apk_call[1]["env"]["ONEXRAY_ANDROID_COMPRESS_NATIVE_LIBS"], "1"
            )
            self.assertEqual(
                (workspace / "output/OneXray-android-arm64-v8a.apk").read_bytes(),
                b"arm64-v8a",
            )
            self.assertEqual(
                (workspace / "output/OneXray-android-x86_64.apk").read_bytes(),
                b"x86_64",
            )


if __name__ == "__main__":
    unittest.main()
