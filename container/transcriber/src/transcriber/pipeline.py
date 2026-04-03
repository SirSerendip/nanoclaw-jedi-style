from __future__ import annotations

import logging
import os
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Optional, Tuple

import ffmpeg
import torch
from faster_whisper import WhisperModel
from faster_whisper.transcribe import Segment, Word
from pyannote.audio import Pipeline as DiarizationPipeline
from pyannote.core import Annotation

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
    model_name: str = "medium.en"
    compute_type: Optional[str] = None
    diarization_token: Optional[str] = None
    language: Optional[str] = None
    beam_size: int = 5
    best_of: int = 5


@dataclass
class TranscriptionResult:
    transcript: str
    speakers: int
    words: int
    duration: float


class TranscriptionPipeline:
    """Transcribe audio and combine with Pyannote diarization."""

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

        hf_token = (
            self.config.diarization_token
            or os.getenv("HUGGINGFACE_TOKEN")
            or os.getenv("HF_TOKEN")
        )
        if not hf_token:
            raise RuntimeError(
                "Hugging Face token required for diarization. "
                "Set HUGGINGFACE_TOKEN in the environment or pass --hf-token."
            )

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
                # Report every 5% to avoid flooding
                if whisper_pct >= last_reported_pct + 5:
                    last_reported_pct = whisper_pct
                    self.on_progress(
                        whisper_pct,
                        f"Transcribing... {segment.end:.0f}s/{total_duration:.0f}s",
                    )

        # Phase 3: Speaker diarization (50-90%)
        self.on_progress(50, "Loading diarization model...")
        logger.info("Running diarization with pyannote.audio")
        try:
            diarization_pipeline = DiarizationPipeline.from_pretrained(
                "pyannote/speaker-diarization-3.1",
                use_auth_token=hf_token,
            )
        except Exception as exc:
            raise RuntimeError(
                "Failed to load pyannote/speaker-diarization-3.1. "
                "Confirm that your Hugging Face token has access to the model "
                "(accept conditions at https://huggingface.co/pyannote/speaker-diarization-3.1)."
            ) from exc

        self.on_progress(55, "Speaker diarization in progress...")
        wav_path = convert_to_wav(audio_path)

        diarize_last_pct = 55

        def diarize_hook(
            step_name: str,
            step_artefact: object,
            completed: Optional[int],
            total: Optional[int],
        ) -> None:
            nonlocal diarize_last_pct
            if completed is not None and total is not None and total > 0:
                pct = 55 + int((completed / total) * 35)
                pct = min(pct, 90)
                if pct >= diarize_last_pct + 5:
                    diarize_last_pct = pct
                    self.on_progress(pct, f"Speaker diarization... {step_name}")

        try:
            diarization_annotation: Annotation = diarization_pipeline(
                str(wav_path), hook=diarize_hook
            )
        finally:
            wav_path.unlink(missing_ok=True)

        diarization_segments = _annotation_to_segments(diarization_annotation)

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


def _annotation_to_segments(annotation: Annotation) -> List[Dict[str, float]]:
    results: List[Dict[str, float]] = []
    for segment, _, speaker in annotation.itertracks(yield_label=True):
        results.append(
            {
                "start": segment.start,
                "end": segment.end,
                "speaker": speaker,
            }
        )
    return results


def convert_to_wav(source_path: Path) -> Path:
    """Convert arbitrary audio input to a mono 16 kHz WAV for pyannote."""
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
