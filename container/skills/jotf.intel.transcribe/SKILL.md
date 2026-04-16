---
name: jotf.intel.transcribe
description: Transcribe audio files to text with speaker diarization using Whisper + diarize
domain: intel
version: 0.1.0
tools:
  - mcp__nanoclaw__transcribe_audio
inputs:
  - name: audio_path
    type: file:*
    description: Path to audio file (mp3, m4a, wav, mp4, ogg)
outputs:
  - name: transcript
    type: file:md
    description: Markdown transcript with timestamps and speaker labels
---

# Audio Transcription

You can transcribe audio files to Markdown with speaker labels and timestamps.

## How to use

**Before transcribing, always ask the user how many people were in the meeting/recording.** Speaker count dramatically improves diarization accuracy. Without it, the model tends to over-segment and invent extra speakers. If the user isn't sure, ask for an approximate range.

Then call the `transcribe_audio` MCP tool:

```
transcribe_audio(audio_path="/workspace/group/recording.mp3", max_speakers=2)
```

The tool supports mp3, m4a, wav, mp4, ogg, and any format ffmpeg can read.

## What you get back

A Markdown transcript with timestamps and speaker attribution:

```
[00:00:02.520 --> 00:00:16.900] **Speaker 1**: Hello there...
[00:00:17.820 --> 00:00:20.980] **Speaker 2**: I'm going to be...
```

## Options

- `model`: Always use `small.en` (the default). Do NOT use medium.en or larger — they are too slow on CPU and the quality difference is negligible for meeting transcription.
- `language`: ISO language code for non-English audio (e.g., `es`, `fr`). Auto-detected if omitted.
- `max_speakers`: Maximum number of speakers expected. Pass this when you know the count — it improves accuracy.

## Important: Always post transcript in chat

When transcription completes, you MUST post the full transcript text directly in your response so it appears in the chat conversation. Do NOT just save it to a file. The transcript needs to be in the conversation context so users can discuss it and follow-up skills (like meeting analysis) can access it.

If the transcript is very long, use `send_message` to post it immediately, then summarize in your final response.

## Notes

- Transcription runs in a separate container — it may take a few minutes for long audio
- Progress is reported to the ops channel automatically
- First run downloads ML models which are cached for subsequent runs
- Runs on CPU (no GPU required), ~8x faster than real-time
- No HuggingFace token needed
