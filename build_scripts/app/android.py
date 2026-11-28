import os
import shutil
from pathlib import Path

from app.builder import Builder
from app.command_line import flutter_command, run_command


class AndroidBuilder(Builder):
    def build_app(self):
        apk_only = os.environ.get("ONEXRAY_ANDROID_APK_ONLY") == "1"
        symbols_dir = Path(self.root_dir) / "build/app/outputs/symbols/android"
        if apk_only:
            run_command(
                [
                    flutter_command(),
                    "build",
                    "apk",
                    "--release",
                    "--split-per-abi",
                    "--target-platform",
                    "android-arm64,android-x64",
                    "--obfuscate",
                    f"--split-debug-info={symbols_dir}",
                ],
                cwd=self.root_dir,
                env={"ONEXRAY_ANDROID_COMPRESS_NATIVE_LIBS": "1"},
            )
            for abi in ("arm64-v8a", "x86_64"):
                shutil.copy2(
                    Path(self.root_dir)
                    / f"build/app/outputs/flutter-apk/app-{abi}-release.apk",
                    Path(self.output_dir) / f"OneXray-android-{abi}.apk",
                )
            return

        run_command(
            [
                flutter_command(),
                "build",
                "appbundle",
                "--target-platform",
                "android-arm64,android-x64",
                "--obfuscate",
                f"--split-debug-info={symbols_dir}",
            ],
            cwd=self.root_dir,
        )
        run_command(
            ["fastlane", "deploy", "--verbose"],
            cwd=self.project_dir,
            env={"ONEXRAY_BUILD_NUMBER": str(self.build_number)},
        )
        shutil.copy2(
            Path(self.root_dir) / "build/app/outputs/bundle/release/app-release.aab",
            self.output_dir,
        )
