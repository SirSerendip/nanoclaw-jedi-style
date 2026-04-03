from __future__ import annotations

import gc
import logging
import math
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
    model_name: str = "small.en"
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

        # Free Whisper model memory before diarization
        del whisper_model
        gc.collect()

        self.on_progress(55, "Speaker diarization in progress...")
        wav_path = convert_to_wav(audio_path)

        try:
            diarization_segments = chunked_diarize(
                wav_path,
                total_duration,
                diarization_pipeline,
                on_progress=self.on_progress,
            )
        finally:
            wav_path.unlink(missing_ok=True)

        # Free diarization model memory before merge
        del diarization_pipeline
        gc.collect()

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


# --- Chunked diarization for long audio ---

CHUNK_DURATION_S = 600  # 10-minute chunks
OVERLAP_S = 30  # 30-second overlap for speaker matching


def chunked_diarize(
    wav_path: Path,
    total_duration: float,
    diarization_pipeline: object,
    on_progress: ProgressCallback = _noop_progress,
) -> List[Dict[str, float]]:
    """Run diarization in memory-safe chunks with speaker matching across boundaries.

    Short audio (<=CHUNK_DURATION_S) runs in a single pass.
    Longer audio is split into overlapping chunks, diarized independently,
    and speakers are matched across boundaries using temporal overlap.
    """
    if total_duration <= CHUNK_DURATION_S + OVERLAP_S:
        # Short audio — single pass
        logger.info("Audio %.0fs, running diarization in single pass", total_duration)

        def single_hook(*args, **kwargs) -> None:
            completed = kwargs.get("completed")
            total = kwargs.get("total")
            if completed is not None and total is not None and total > 0:
                pct = 55 + int((completed / total) * 35)
                on_progress(min(pct, 89), "Speaker diarization...")

        annotation = diarization_pipeline(str(wav_path), hook=single_hook)
        return _annotation_to_segments(annotation)

    # Long audio — chunked processing
    num_chunks = math.ceil((total_duration - OVERLAP_S) / CHUNK_DURATION_S)
    num_chunks = max(num_chunks, 1)
    logger.info(
        "Audio %.0fs, running chunked diarization (%d chunks of %ds with %ds overlap)",
        total_duration,
        num_chunks,
        CHUNK_DURATION_S,
        OVERLAP_S,
    )

    all_segments: List[Dict[str, float]] = []
    global_speakers: Dict[str, str] = {}  # local label -> global label
    next_speaker_id = 0

    for chunk_idx in range(num_chunks):
        start_s = chunk_idx * CHUNK_DURATION_S
        end_s = min(start_s + CHUNK_DURATION_S + OVERLAP_S, total_duration)

        pct = 55 + int((chunk_idx / num_chunks) * 35)
        on_progress(
            min(pct, 89),
            f"Speaker diarization... chunk {chunk_idx + 1}/{num_chunks}",
        )

        # Extract chunk audio
        chunk_wav = _extract_audio_chunk(wav_path, start_s, end_s)
        try:
            annotation = diarization_pipeline(str(chunk_wav))
        finally:
            chunk_wav.unlink(missing_ok=True)

        chunk_segments = _annotation_to_segments(annotation)

        # Offset to absolute times
        for seg in chunk_segments:
            seg["start"] += start_s
            seg["end"] += start_s

        # Free memory between chunks
        del annotation
        gc.collect()

        if chunk_idx == 0:
            # First chunk: assign global speaker IDs directly
            for seg in chunk_segments:
                local = seg["speaker"]
                if local not in global_speakers:
                    global_speakers[local] = f"SPEAKER_{next_speaker_id:02d}"
                    next_speaker_id += 1
                seg["speaker"] = global_speakers[local]
            all_segments.extend(chunk_segments)
        else:
            # Match speakers using the overlap region
            overlap_start = start_s
            overlap_end = start_s + OVERLAP_S

            chunk_map = _match_overlap_speakers(
                all_segments, chunk_segments, overlap_start, overlap_end
            )

            # Assign global IDs to any new speakers not seen in overlap
            for seg in chunk_segments:
                local = seg["speaker"]
                if local not in chunk_map:
                    chunk_map[local] = f"SPEAKER_{next_speaker_id:02d}"
                    next_speaker_id += 1

            # Add segments AFTER the overlap (overlap is already covered by prev chunk)
            for seg in chunk_segments:
                if seg["end"] > overlap_end:
                    seg["speaker"] = chunk_map.get(seg["speaker"], seg["speaker"])
                    if seg["start"] < overlap_end:
                        seg["start"] = overlap_end
                    all_segments.append(seg)

        logger.info(
            "Chunk %d/%d done, %d segments so far, %d global speakers",
            chunk_idx + 1,
            num_chunks,
            len(all_segments),
            next_speaker_id,
        )

    return all_segments


def _match_overlap_speakers(
    prev_segments: List[Dict[str, float]],
    curr_segments: List[Dict[str, float]],
    overlap_start: float,
    overlap_end: float,
) -> Dict[str, str]:
    """Match speakers between chunks using temporal overlap in the shared region."""
    prev_in_overlap = [
        s for s in prev_segments if s["end"] > overlap_start and s["start"] < overlap_end
    ]
    curr_in_overlap = [
        s for s in curr_segments if s["end"] > overlap_start and s["start"] < overlap_end
    ]

    if not prev_in_overlap or not curr_in_overlap:
        return {}

    mapping: Dict[str, str] = {}
    used_prev: set = set()
    curr_speakers = sorted(
        set(s["speaker"] for s in curr_in_overlap),
        key=lambda sp: sum(
            s["end"] - s["start"] for s in curr_in_overlap if s["speaker"] == sp
        ),
        reverse=True,
    )

    for curr_spk in curr_speakers:
        curr_segs = [s for s in curr_in_overlap if s["speaker"] == curr_spk]
        best_overlap = 0.0
        best_prev = None

        for prev_spk in set(s["speaker"] for s in prev_in_overlap):
            if prev_spk in used_prev:
                continue
            prev_segs = [s for s in prev_in_overlap if s["speaker"] == prev_spk]
            total = sum(
                _overlap(c["start"], c["end"], p["start"], p["end"])
                for c in curr_segs
                for p in prev_segs
            )
            if total > best_overlap:
                best_overlap = total
                best_prev = prev_spk

        if best_prev is not None and best_overlap > 0:
            mapping[curr_spk] = best_prev
            used_prev.add(best_prev)

    return mapping


def _extract_audio_chunk(source_path: Path, start_s: float, end_s: float) -> Path:
    """Extract a chunk of audio to a temp WAV file."""
    fd, tmp_path = tempfile.mkstemp(suffix=".wav", prefix="chunk-")
    os.close(fd)
    output_path = Path(tmp_path)
    duration = end_s - start_s
    (
        ffmpeg.input(str(source_path), ss=start_s, t=duration)
        .output(str(output_path), format="wav", ac=1, ar=16000)
        .overwrite_output()
        .run(quiet=True)
    )
    return output_path


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
