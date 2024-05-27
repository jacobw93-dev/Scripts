#!/data/data/com.termux/files/usr/bin/python
from __future__ import annotations

import colorsys
import logging
import math
import os
import random
import shutil
import string
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageFile, ImageOps, UnidentifiedImageError

# =============================================================================
# CONFIGURATION
# =============================================================================

ANDROID_ROOT = Path("/sdcard/Pictures/.hide")

SOURCE_DIRECTORIES = [
    ANDROID_ROOT / "Reddit",
    ANDROID_ROOT / "readchan",
]

EXCLUDED_EXTENSIONS = {".gif", ".mp4", ".webm"}

QUARANTINE_DIRECTORY = ANDROID_ROOT / "gif"
UNSORTED_DIRECTORY = ANDROID_ROOT / "unsorted"
SORTED_DIRECTORY = ANDROID_ROOT / "sorted"
LOG_DIRECTORY = ANDROID_ROOT / "logs"

JPEG_QUALITY = 90
DELETE_WEBP_AFTER_CONVERSION = True
REMOVE_EMPTY_DIRECTORIES = True
RENAME_IMAGES = True
ENABLE_NOTIFICATION = True

VALID_SORT_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp"}

ANALYSIS_FIRST_SIZE = (32, 32)
ANALYSIS_FINAL_SIZE = (10, 10)

ImageFile.LOAD_TRUNCATED_IMAGES = True

# =============================================================================
# ANSI COLORS
# =============================================================================

RESET = "\033[0m"
CYAN = "\033[96m"
YELLOW = "\033[93m"
GREEN = "\033[92m"
RED = "\033[91m"
GRAY = "\033[90m"

# =============================================================================
# STATS
# =============================================================================

@dataclass
class Stats:
    scanned: int = 0
    moved_to_unsorted: int = 0
    quarantined: int = 0
    extensions_corrected: int = 0
    webp_converted: int = 0
    webp_failed: int = 0
    analyzed: int = 0
    analysis_failed: int = 0
    renamed: int = 0
    empty_directories_removed: int = 0

stats = Stats()

# =============================================================================
# LOGGING / OUTPUT
# =============================================================================

def configure_logging() -> Path:
    LOG_DIRECTORY.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    log_file = LOG_DIRECTORY / f"image_processing_{timestamp}.log"

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)-7s | %(message)s",
        handlers=[logging.FileHandler(log_file, encoding="utf-8")],
    )
    return log_file

def section(title: str) -> None:
    separator = "=" * 80
    print()
    print(f"{CYAN}{separator}{RESET}")
    print(f"{CYAN}{title}{RESET}")
    print(f"{CYAN}{separator}{RESET}")
    logging.info(separator)
    logging.info(title)
    logging.info(separator)

def info(message: str) -> None:
    print(message)
    logging.info(message)

def success(message: str) -> None:
    print(f"{GREEN}{message}{RESET}")
    logging.info(message)

def warning(message: str) -> None:
    print(f"{YELLOW}WARNING: {message}{RESET}")
    logging.warning(message)

def error(message: str) -> None:
    print(f"{RED}ERROR: {message}{RESET}")
    logging.error(message)

def action(message: str) -> None:
    print(f"{YELLOW}{message}{RESET}")
    logging.info(message)

def debug_message(message: str) -> None:
    print(f"{GRAY}{message}{RESET}")
    logging.info(message)

# =============================================================================
# FILE HELPERS
# =============================================================================

def safe_destination(directory: Path, filename: str) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    candidate = directory / filename
    if not candidate.exists():
        return candidate

    source = Path(filename)
    stem = source.stem
    suffix = source.suffix
    counter = 1

    while True:
        candidate = directory / f"{stem}_{counter}{suffix}"
        if not candidate.exists():
            return candidate
        counter += 1

def move_file_safely(source: Path, destination_directory: Path) -> Path:
    destination = safe_destination(destination_directory, source.name)
    action(f"Moving:\n  FROM: {source}\n  TO:   {destination}")
    shutil.move(str(source), str(destination))
    return destination

# =============================================================================
# FILE TYPE DETECTION
# =============================================================================

def detect_file_extension(path: Path) -> str | None:
    try:
        with path.open("rb") as handle:
            header = handle.read(32)
    except OSError as exc:
        warning(f"Cannot read file header: {path}: {exc}")
        return None

    if len(header) >= 3 and header[:3] == b"\xff\xd8\xff":
        return ".jpg"
    if len(header) >= 8 and header[:8] == b"\x89PNG\r\n\x1a\n":
        return ".png"
    if len(header) >= 6 and header[:6] in (b"GIF87a", b"GIF89a"):
        return ".gif"
    if len(header) >= 2 and header[:2] == b"BM":
        return ".bmp"
    if len(header) >= 12 and header[:4] == b"RIFF" and header[8:12] == b"WEBP":
        return ".webp"

    return None

# =============================================================================
# SOURCE PROCESSING
# =============================================================================

def quarantine_excluded_media() -> None:
    section("1. Moving excluded media to quarantine")
    QUARANTINE_DIRECTORY.mkdir(parents=True, exist_ok=True)

    for source_directory in SOURCE_DIRECTORIES:
        info(f"Checking: {source_directory}")
        if not source_directory.exists():
            warning(f"Source directory does not exist: {source_directory}")
            continue

        files = [p for p in source_directory.rglob("*") if p.is_file()]

        for source_file in files:
            stats.scanned += 1
            if source_file.suffix.lower() not in EXCLUDED_EXTENSIONS:
                continue
            try:
                move_file_safely(source_file, QUARANTINE_DIRECTORY)
                stats.quarantined += 1
            except Exception as exc:
                warning(f"Failed to quarantine {source_file}: {exc}")

def move_source_images_to_unsorted() -> None:
    section("2. Moving source files to unsorted")
    UNSORTED_DIRECTORY.mkdir(parents=True, exist_ok=True)

    for source_directory in SOURCE_DIRECTORIES:
        if not source_directory.exists():
            warning(f"Source directory does not exist: {source_directory}")
            continue

        files = [p for p in source_directory.rglob("*") if p.is_file()]

        if not files:
            info(f"No remaining files found in: {source_directory}")
            continue

        for source_file in files:
            try:
                move_file_safely(source_file, UNSORTED_DIRECTORY)
                stats.moved_to_unsorted += 1
            except Exception as exc:
                warning(f"Failed to move {source_file}: {exc}")

# =============================================================================
# EXTENSION RESTORATION
# =============================================================================

def restore_correct_extensions() -> None:
    section("3. Restoring correct image extensions")

    files = [p for p in UNSORTED_DIRECTORY.iterdir() if p.is_file()]

    for path in files:
        detected_extension = detect_file_extension(path)

        if detected_extension is None:
            debug_message(f"Unknown/non-image type, keeping unchanged: {path.name}")
            continue

        current_extension = path.suffix.lower()

        if current_extension == detected_extension:
            info(f"OK: {path.name}")
            continue

        destination = safe_destination(path.parent, f"{path.stem}{detected_extension}")
        action(f"Correcting extension: {path.name} -> {destination.name}")

        try:
            path.rename(destination)
            stats.extensions_corrected += 1
        except Exception as exc:
            warning(f"Could not rename {path}: {exc}")

# =============================================================================
# WEBP CONVERSION
# =============================================================================

def convert_webp_to_jpeg() -> None:
    section(f"4. Converting WEBP to JPEG (quality {JPEG_QUALITY})")

    webp_files = [
        p for p in UNSORTED_DIRECTORY.iterdir()
        if p.is_file() and p.suffix.lower() == ".webp"
    ]

    if not webp_files:
        info("No WEBP files found.")
        return

    total = len(webp_files)

    for index, source in enumerate(webp_files, start=1):
        destination = safe_destination(source.parent, f"{source.stem}.jpg")
        info(f"[{index}/{total}] {source.name}")

        try:
            with Image.open(source) as image:
                image = ImageOps.exif_transpose(image)

                if image.mode in ("RGBA", "LA"):
                    rgba = image.convert("RGBA")
                    background = Image.new("RGB", rgba.size, (255, 255, 255))
                    background.paste(rgba, mask=rgba.getchannel("A"))
                    output = background
                else:
                    output = image.convert("RGB")

                output.save(
                    destination,
                    "JPEG",
                    quality=JPEG_QUALITY,
                    optimize=True,
                )

            with Image.open(destination) as check:
                check.verify()

            if destination.exists() and destination.stat().st_size > 0:
                success(f"Converted: {source.name} -> {destination.name}")
                stats.webp_converted += 1

                if DELETE_WEBP_AFTER_CONVERSION:
                    source.unlink()
                    debug_message(f"Deleted source WEBP: {source.name}")
            else:
                raise RuntimeError("Generated JPEG is empty.")

        except Exception as exc:
            stats.webp_failed += 1
            warning(f"WEBP conversion failed for {source.name}: {exc}")
            try:
                if destination.exists():
                    destination.unlink()
            except OSError:
                pass

# =============================================================================
# COLOR ANALYSIS
# =============================================================================

@dataclass
class ImageColor:
    path: Path
    hue: float
    saturation: float
    lightness: float

def calculate_average_hsl(path: Path) -> ImageColor | None:
    try:
        with Image.open(path) as image:
            image = ImageOps.exif_transpose(image)

            if image.mode in ("RGBA", "LA"):
                rgba = image.convert("RGBA")
                background = Image.new("RGB", rgba.size, (255, 255, 255))
                background.paste(rgba, mask=rgba.getchannel("A"))
                image = background
            else:
                image = image.convert("RGB")

            image.thumbnail(ANALYSIS_FIRST_SIZE, Image.Resampling.LANCZOS)
            image = image.resize(ANALYSIS_FINAL_SIZE, Image.Resampling.BILINEAR)
            pixels = list(image.getdata())

        if not pixels:
            return None

        hue_values = []
        saturation_values = []
        lightness_values = []

        for red, green, blue in pixels:
            h, l, s = colorsys.rgb_to_hls(red / 255.0, green / 255.0, blue / 255.0)
            hue_values.append(h * 360.0)
            saturation_values.append(s * 100.0)
            lightness_values.append(l * 100.0)

        sin_sum = 0.0
        cos_sum = 0.0

        for hue in hue_values:
            radians = math.radians(hue)
            sin_sum += math.sin(radians)
            cos_sum += math.cos(radians)

        average_hue = math.degrees(
            math.atan2(
                sin_sum / len(hue_values),
                cos_sum / len(hue_values),
            )
        )

        if average_hue < 0:
            average_hue += 360.0

        average_saturation = sum(saturation_values) / len(saturation_values)
        average_lightness = sum(lightness_values) / len(lightness_values)

        return ImageColor(
            path=path,
            hue=round(average_hue, 3),
            saturation=round(average_saturation, 3),
            lightness=round(average_lightness, 3),
        )

    except (UnidentifiedImageError, OSError, ValueError) as exc:
        warning(f"Cannot analyze {path.name}: {exc}")
        return None
    except Exception as exc:
        warning(f"Unexpected error analyzing {path.name}: {exc}")
        return None

def format_number(value: float) -> str:
    return f"{value:.3f}".rstrip("0").rstrip(".")

def analyze_images() -> list[ImageColor]:
    section("5. Analyzing image colors")

    image_files = [
        p for p in UNSORTED_DIRECTORY.iterdir()
        if p.is_file() and p.suffix.lower() in VALID_SORT_EXTENSIONS
    ]

    total = len(image_files)

    if total == 0:
        warning("No JPG/JPEG/PNG/BMP images found.")
        return []

    info(f"Images to analyze: {total}")

    results: list[ImageColor] = []
    start = time.monotonic()

    for index, path in enumerate(image_files, start=1):
        color = calculate_average_hsl(path)

        if color is None:
            stats.analysis_failed += 1
            continue

        results.append(color)
        stats.analyzed += 1

        elapsed = time.monotonic() - start
        average_seconds = elapsed / index
        remaining_seconds = average_seconds * (total - index)

        print(
            f"\r"
            f"[{index:>5}/{total}] "
            f"{path.name[:35]:<35} "
            f"H={color.hue:>7.3f} "
            f"S={color.saturation:>7.3f} "
            f"L={color.lightness:>7.3f} "
            f"ETA={remaining_seconds:>7.1f}s",
            end="",
            flush=True,
        )

    print()
    return results

# =============================================================================
# SORT + RENAME
# =============================================================================

def generate_run_id(length: int = 6) -> str:
    characters = string.digits + "abcdef"
    return "".join(random.choice(characters) for _ in range(length))

def rename_sorted_images(image_colors: list[ImageColor]) -> None:
    section("6. Sorting and renaming images")

    if not image_colors:
        warning("No successfully analyzed images available for renaming.")
        return

    sorted_images = sorted(
        image_colors,
        key=lambda item: (-item.lightness, item.hue),
    )

    run_id = generate_run_id()
    info(f"Run ID: {run_id}")
    info(f"Images to rename: {len(sorted_images)}")

    temporary_items = []

    for counter, image in enumerate(sorted_images, start=1):
        original_path = image.path

        temporary_path = (
            original_path.parent
            / f".tmp_colorsort_{run_id}_{counter:06d}{original_path.suffix.lower()}"
        )

        collision_counter = 1

        while temporary_path.exists():
            temporary_path = (
                original_path.parent
                / f".tmp_colorsort_{run_id}_{counter:06d}_{collision_counter}{original_path.suffix.lower()}"
            )
            collision_counter += 1

        original_path.rename(temporary_path)
        temporary_items.append((temporary_path, image, counter))

    total = len(temporary_items)

    for index, (temporary_path, image, counter) in enumerate(temporary_items, start=1):
        extension = temporary_path.suffix.lower()

        filename = (
            f"H{format_number(image.hue)}_"
            f"S{format_number(image.saturation)}_"
            f"L{format_number(image.lightness)}_"
            f"{run_id}_"
            f"{counter:04d}"
            f"{extension}"
        )

        destination = safe_destination(SORTED_DIRECTORY, filename)
        temporary_path.rename(destination)

        stats.renamed += 1

        print(
            f"\rRenaming {index}/{total}: {destination.name[:55]}",
            end="",
            flush=True,
        )

    print()
    success(f"Renamed and moved {stats.renamed} images to: {SORTED_DIRECTORY}")

# =============================================================================
# CLEANUP
# =============================================================================

def remove_empty_directories() -> None:
    section("7. Removing empty source directories")

    if not REMOVE_EMPTY_DIRECTORIES:
        info("Empty-directory cleanup disabled.")
        return

    for source_root in SOURCE_DIRECTORIES:
        if not source_root.exists():
            continue

        directories = [p for p in source_root.rglob("*") if p.is_dir()]
        directories.sort(key=lambda p: len(p.parts), reverse=True)

        for directory in directories:
            try:
                if not any(directory.iterdir()):
                    directory.rmdir()
                    stats.empty_directories_removed += 1
                    debug_message(f"Removed empty directory: {directory}")
            except OSError:
                pass

        try:
            if source_root.exists() and not any(source_root.iterdir()):
                source_root.rmdir()
                stats.empty_directories_removed += 1
                debug_message(f"Removed empty source directory: {source_root}")
        except OSError:
            pass

# =============================================================================
# ANDROID MEDIA DATABASE
# =============================================================================

def refresh_android_media_database() -> None:
    section("8. Refreshing Android media database")

    try:
        subprocess.run(
            [
                "am",
                "broadcast",
                "-a",
                "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
                "-d",
                f"file://{SORTED_DIRECTORY}",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        success("Requested Android media rescan.")
    except Exception as exc:
        warning(f"Could not request media rescan: {exc}")

# =============================================================================
# NOTIFICATION
# =============================================================================

def send_android_notification(title: str, message: str) -> None:
    if not ENABLE_NOTIFICATION:
        return

    command = shutil.which("termux-notification")

    if command is None:
        debug_message("termux-notification is unavailable; notification skipped.")
        return

    try:
        subprocess.run(
            [command, "--title", title, "--content", message],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception as exc:
        warning(f"Notification failed: {exc}")

# =============================================================================
# VALIDATION / SUMMARY
# =============================================================================

def validate_environment() -> None:
    section("Initial validation")

    info(f"Date:       {datetime.now():%Y-%m-%d %H:%M:%S}")
    info(f"Python:     {sys.version.split()[0]}")
    info(f"User:       {os.environ.get('USER', 'unknown')}")
    info(f"Storage:    {ANDROID_ROOT}")
    info(f"Unsorted:   {UNSORTED_DIRECTORY}")
    info(f"Sorted:     {SORTED_DIRECTORY}")
    info(f"Quarantine: {QUARANTINE_DIRECTORY}")

    if not Path("/sdcard").exists():
        raise RuntimeError(
            "/sdcard is not accessible. Run termux-setup-storage and allow storage access."
        )

    try:
        ANDROID_ROOT.mkdir(parents=True, exist_ok=True)
        UNSORTED_DIRECTORY.mkdir(parents=True, exist_ok=True)
        SORTED_DIRECTORY.mkdir(parents=True, exist_ok=True)
        QUARANTINE_DIRECTORY.mkdir(parents=True, exist_ok=True)
    except PermissionError as exc:
        raise RuntimeError(
            f"Termux cannot access Android shared storage: {exc}"
        )

    for source in SOURCE_DIRECTORIES:
        if source.exists():
            success(f"Source available: {source}")
        else:
            warning(f"Source not currently present: {source}")

def print_summary(elapsed_seconds: float, log_file: Path) -> None:
    section("Processing summary")

    hours, remainder = divmod(int(elapsed_seconds), 3600)
    minutes, seconds = divmod(remainder, 60)

    info(f"Files quarantined:             {stats.quarantined}")
    info(f"Files moved to unsorted:       {stats.moved_to_unsorted}")
    info(f"Extensions corrected:          {stats.extensions_corrected}")
    info(f"WEBP converted:                {stats.webp_converted}")
    info(f"WEBP conversion failures:      {stats.webp_failed}")
    info(f"Images analyzed:               {stats.analyzed}")
    info(f"Image analysis failures:       {stats.analysis_failed}")
    info(f"Images renamed:                {stats.renamed}")
    info(f"Empty directories removed:     {stats.empty_directories_removed}")
    info(f"Elapsed time:                   {hours:02d}:{minutes:02d}:{seconds:02d}")
    info(f"Log file:\n  {log_file}")

# =============================================================================
# MAIN
# =============================================================================

def main() -> int:
    start_time = time.monotonic()
    log_file = configure_logging()

    try:
        validate_environment()
        quarantine_excluded_media()
        move_source_images_to_unsorted()
        restore_correct_extensions()
        convert_webp_to_jpeg()

        image_colors = analyze_images()

        if RENAME_IMAGES:
            rename_sorted_images(image_colors)

        remove_empty_directories()
        refresh_android_media_database()

        elapsed = time.monotonic() - start_time
        print_summary(elapsed, log_file)

        success("Completed successfully.")

        send_android_notification(
            "Image processing complete",
            (
                f"Analyzed {stats.analyzed}; "
                f"renamed {stats.renamed}; "
                f"WEBP converted {stats.webp_converted}."
            ),
        )

        return 0

    except KeyboardInterrupt:
        print()
        warning("Execution interrupted by user.")
        logging.warning("Execution interrupted by user.")
        send_android_notification(
            "Image processing interrupted",
            "The image processing script was stopped.",
        )
        return 130

    except Exception as exc:
        error(str(exc))
        logging.exception("Fatal execution error")
        send_android_notification(
            "Image processing failed",
            str(exc)[:200],
        )
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
