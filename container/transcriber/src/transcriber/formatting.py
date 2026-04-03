from __future__ import annotations

from typing import Dict, Iterable, List


def build_markdown_transcript(segments: Iterable[Dict]) -> str:
    speaker_aliases = _build_speaker_map(segments)
    lines: List[str] = ["# Transcript", ""]
    for segment in segments:
        speaker = speaker_aliases.get(segment.get("speaker", ""), "Speaker ?")
        start = format_timestamp(segment.get("start", 0.0))
        end = format_timestamp(segment.get("end", 0.0))
        text = segment.get("text", "").strip()
        if not text:
            continue
        lines.append(f"[{start} --> {end}] **{speaker}**: {text}")
    lines.append("")
    return "\n".join(lines)


def _build_speaker_map(segments: Iterable[Dict]) -> Dict[str, str]:
    mapping: Dict[str, str] = {}
    ordinal = 1
    for segment in segments:
        label = segment.get("speaker")
        if not label or label in mapping:
            continue
        mapping[label] = f"Speaker {ordinal}"
        ordinal += 1
    return mapping


def count_words(transcript: str) -> int:
    return len(transcript.split())


def count_speakers(segments: Iterable[Dict]) -> int:
    speakers = set()
    for segment in segments:
        label = segment.get("speaker")
        if label:
            speakers.add(label)
    return len(speakers)


def format_timestamp(seconds: float) -> str:
    if seconds is None:
        return "00:00:00.000"
    total_ms = int(round(seconds * 1000))
    hours, remainder = divmod(total_ms, 3600_000)
    minutes, remainder = divmod(remainder, 60_000)
    secs, milliseconds = divmod(remainder, 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}.{milliseconds:03d}"
