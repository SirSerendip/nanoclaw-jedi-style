from __future__ import annotations

import gc
import logging
import os
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Optional, Tuple

import ffmpeg
import torch
from diarize import diarize as run_diarize
from faster_whisper import WhisperModel
from faster_whisper.transcribe import Segment

from .formatting import build_markdown_transcript, count_speakers, count_words

logger = logging.getLogger(__name__)

# Type for progress callback: (percent: int, detail: str) -> None
ProgressCallback = Callable[[int, str], None]


def _noop_progress(_pct: int, _detail: str) -> None:
    pass


def resolve_device() -> str:
    if torch.cuda.is_available():
        return "cuda"
    return "cpu"


@dataclass
class TranscriptionPipelineConfig:
    audio_path: Path
    model_name: str = "small.en"
    compute_type: Optional[str] = None
    language: Optional[str] = None
    beam_size: int = 5
    best_of: int = 5
    max_speakers: Optional[int] = None


@dataclass
class TranscriptionResult:
    transcript: str
    speakers: int
    words: int
    duration: float


class TranscriptionPipeline:
    """Transcribe audio and combine with speaker diarization."""

    def __init__(
        self,
        config: TranscriptionPipelineConfig,
        on_progress: ProgressCallback = _noop_progress,
    ) -> None:
        self.config = config
        self.device = resolve_device()
        self.compute_type = config.compute_type or self._default_compute_type()
        self.on_progress = on_progress

    def run(self) -> TranscriptionResult:
        audio_path = self.config.audio_path
        if not audio_path.exists():
            raise FileNotFoundError(f"Audio file not found: {audio_path}")

        # Phase 1: Load Whisper model (0-5%)
        self.on_progress(2, "Loading Whisper model...")
        logger.info(
            "Loading Whisper model %s (device=%s, compute_type=%s)",
            self.config.model_name,
            self.device,
            self.compute_type,
        )
        whisper_model = WhisperModel(
            self.config.model_name,
            device=self.device,
            compute_type=self.compute_type,
        )

        # Phase 2: Transcribe with Whisper (5-50%)
        self.on_progress(5, "Transcribing audio...")
        logger.info("Transcribing audio via faster-whisper")
        segments_iter, transcription_info = whisper_model.transcribe(
            str(audio_path),
            beam_size=self.config.beam_size,
            best_of=self.config.best_of,
            language=self.config.language,
            word_timestamps=True,
            condition_on_previous_text=False,
        )

        total_duration = transcription_info.duration or 0.0
        detected_language = transcription_info.language
        logger.info(
            "Detected language: %s (probability %.2f), duration: %.1fs",
            detected_language,
            transcription_info.language_probability,
            total_duration,
        )

        transcription_segments: list[Segment] = []
        last_reported_pct = 5
        for segment in segments_iter:
            transcription_segments.append(segment)
            if total_duration > 0:
                whisper_pct = 5 + int((segment.end / total_duration) * 45)
                whisper_pct = min(whisper_pct, 50)
                if whisper_pct >= last_reported_pct + 5:
                    last_reported_pct = whisper_pct
                    self.on_progress(
                        whisper_pct,
                        f"Transcribing... {segment.end:.0f}s/{total_duration:.0f}s",
                    )

        # Free Whisper model memory before diarization
        del whisper_model
        gc.collect()

        # Phase 3: Speaker diarization (50-90%)
        self.on_progress(50, "Running speaker diarization...")
        logger.info("Running diarization with diarize library")

        wav_path = convert_to_wav(audio_path)

        try:
            diarize_kwargs: dict = {}
            if self.config.max_speakers is not None:
                diarize_kwargs["max_speakers"] = self.config.max_speakers
                logger.info("max_speakers=%d", self.config.max_speakers)

            self.on_progress(55, "Speaker diarization in progress...")
            result = run_diarize(str(wav_path), **diarize_kwargs)
            diarization_segments = _diarize_to_segments(result)

            logger.info(
                "Diarization complete: %d segments, %d speakers",
                len(diarization_segments),
                result.num_speakers,
            )
        finally:
            wav_path.unlink(missing_ok=True)

        gc.collect()
        self.on_progress(89, "Diarization complete")

        # Phase 4: Merge and format (90-100%)
        self.on_progress(90, "Merging transcription with speakers...")
        logger.info("Merging transcription with diarization")
        enriched_segments = assign_speakers(transcription_segments, diarization_segments)

        self.on_progress(95, "Formatting transcript...")
        transcript = build_markdown_transcript(enriched_segments)
        speakers = count_speakers(enriched_segments)
        words = count_words(transcript)

        self.on_progress(100, f"Complete ({speakers} speakers, {words} words)")

        return TranscriptionResult(
            transcript=transcript,
            speakers=speakers,
            words=words,
            duration=total_duration,
        )

    def _default_compute_type(self) -> str:
        if self.device == "cuda":
            return "float16"
        return "int8"


def _diarize_to_segments(result) -> List[Dict[str, float]]:
    """Convert diarize library result to our internal segment format."""
    segments = []
    for seg in result.segments:
        segments.append(
            {
                "start": seg.start,
                "end": seg.end,
                "speaker": seg.speaker,
            }
        )
    return segments


def assign_speakers(
    segments: Iterable[Segment],
    diarization_segments: List[Dict[str, float]],
) -> List[Dict[str, object]]:
    """Assign speaker labels to faster-whisper segments using diarization windows."""
    diarization_segments = sorted(diarization_segments, key=lambda s: s["start"])
    results: List[Dict[str, object]] = []

    for segment in segments:
        speaker = select_speaker(segment.start, segment.end, diarization_segments)
        text = segment.text.strip()
        if not text:
            continue
        results.append(
            {
                "start": segment.start,
                "end": segment.end,
                "speaker": speaker,
                "text": text,
            }
        )
    return merge_adjacent_by_speaker(results)


def select_speaker(
    start: float, end: float, diarization_segments: List[Dict[str, float]]
) -> str:
    overlaps: List[Tuple[float, str]] = []
    for entry in diarization_segments:
        overlap = _overlap(start, end, entry["start"], entry["end"])
        if overlap > 0:
            overlaps.append((overlap, entry["speaker"]))

    if not overlaps:
        return "Unknown"
    overlaps.sort(reverse=True)
    return overlaps[0][1]


def merge_adjacent_by_speaker(
    segments: List[Dict[str, object]],
) -> List[Dict[str, object]]:
    if not segments:
        return []

    merged: List[Dict[str, object]] = [segments[0].copy()]
    for segment in segments[1:]:
        previous = merged[-1]
        if (
            segment["speaker"] == previous["speaker"]
            and abs(segment["start"] - previous["end"]) < 0.5
        ):
            previous["end"] = segment["end"]
            previous["text"] = f"{previous['text']} {segment['text']}".strip()
            continue
        merged.append(segment.copy())
    return merged


def _overlap(a_start: float, a_end: float, b_start: float, b_end: float) -> float:
    return max(0.0, min(a_end, b_end) - max(a_start, b_start))


def convert_to_wav(source_path: Path) -> Path:
    """Convert arbitrary audio input to a mono 16 kHz WAV for diarization."""
    fd, tmp_path = tempfile.mkstemp(suffix=".wav", prefix="transcriber-")
    os.close(fd)
    output_path = Path(tmp_path)
    try:
        (
            ffmpeg.input(str(source_path))
            .output(str(output_path), format="wav", ac=1, ar=16000)
            .overwrite_output()
            .run(quiet=True)
        )
    except ffmpeg.Error as exc:
        output_path.unlink(missing_ok=True)
        stderr = (
            exc.stderr.decode("utf-8", errors="ignore") if exc.stderr else str(exc)
        )
        raise RuntimeError(
            f"ffmpeg failed while converting {source_path} to wav: {stderr}"
        ) from exc
    return output_path
