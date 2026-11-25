import os
import shutil
from pathlib import Path

from app.builder import Builder
from app.command_line import flutter_command, run_command


class AndroidBuilder(Builder):
    def build_app(self):
        play_service = Path(self.project_dir) / "fastlane/playservice.json"
        apk_only = (
            os.environ.get("ONEXRAY_ANDROID_APK_ONLY") == "1"
            or not play_service.is_file()
        )
        if apk_only:
            run_command(
                [
                    flutter_command(),
                    "build",
                    "apk",
                    "--release",
                    "--target-platform",
                    "android-arm64,android-x64",
                ],
                cwd=self.root_dir,
            )
            shutil.copy2(
                Path(self.root_dir) / "build/app/outputs/flutter-apk/app-release.apk",
                Path(self.output_dir)
                / f"OneXray-android-universal-{self.build_number}.apk",
            )
            return

        run_command(
            [
                flutter_command(),
                "build",
                "appbundle",
                "--target-platform",
                "android-arm64,android-x64",
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
