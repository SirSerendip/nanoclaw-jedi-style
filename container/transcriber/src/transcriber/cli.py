"""CLI entrypoint for the NanoClaw transcriber container.

Outputs:
  - Progress lines to stderr: PROGRESS:{"percent":N,"detail":"..."}
  - Final result to stdout as JSON (--json) or Markdown transcript
"""
from __future__ import annotations

import argparse
import json
import logging
import sys
from pathlib import Path

from .pipeline import TranscriptionPipeline, TranscriptionPipelineConfig


def emit_progress(percent: int, detail: str) -> None:
    """Write a machine-readable progress line to stderr."""
    line = json.dumps({"percent": percent, "detail": detail})
    print(f"PROGRESS:{line}", file=sys.stderr, flush=True)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Transcribe audio with speaker diarization."
    )
    parser.add_argument(
        "--audio",
        required=True,
        type=Path,
        help="Path to audio file.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        dest="json_output",
        help="Output JSON result to stdout instead of plain Markdown.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Write Markdown transcript to this file (in addition to stdout).",
    )
    parser.add_argument(
        "--model",
        default="small.en",
        help="Whisper model name (e.g., small.en, medium.en, large-v2).",
    )
    parser.add_argument(
        "--compute-type",
        default=None,
        help="Compute type (int8, float16). Auto-selected if omitted.",
    )
    parser.add_argument(
        "--max-speakers",
        dest="max_speakers",
        type=int,
        default=None,
        help="Maximum number of speakers expected. Improves accuracy when known.",
    )
    parser.add_argument(
        "--language",
        default=None,
        help="ISO language code override. Leave unset for auto-detection.",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging verbosity.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        stream=sys.stderr,
    )

    audio_path: Path = args.audio.expanduser().resolve()

    config = TranscriptionPipelineConfig(
        audio_path=audio_path,
        model_name=args.model,
        compute_type=args.compute_type,
        language=args.language,
        max_speakers=args.max_speakers,
    )

    pipeline = TranscriptionPipeline(config, on_progress=emit_progress)
    try:
        result = pipeline.run()
    except Exception as exc:
        logging.exception("Transcription failed: %s", exc)
        if args.json_output:
            json.dump({"status": "error", "error": str(exc)}, sys.stdout)
            print()
        return 1

    # Write to file if requested
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(result.transcript, encoding="utf-8")
        logging.info("Saved transcript to %s", args.out)

    # Output to stdout
    if args.json_output:
        json.dump(
            {
                "status": "success",
                "transcript": result.transcript,
                "speakers": result.speakers,
                "words": result.words,
                "duration": round(result.duration, 1),
            },
            sys.stdout,
        )
        print()
    else:
        sys.stdout.write(result.transcript)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
