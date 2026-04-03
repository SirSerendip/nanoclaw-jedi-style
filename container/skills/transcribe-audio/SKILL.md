---
name: Audio Transcription
description: Transcribe audio files to text with speaker diarization using Whisper + pyannote
tools:
  - mcp__nanoclaw__transcribe_audio
---

# Audio Transcription

You can transcribe audio files to Markdown with speaker labels and timestamps.

## How to use

Call the `transcribe_audio` MCP tool with the path to an audio file:

```
transcribe_audio(audio_path="/workspace/group/recording.mp3")
```

The tool supports mp3, m4a, wav, mp4, ogg, and any format ffmpeg can read.

## What you get back

A Markdown transcript with timestamps and speaker attribution:

```
[00:00:02.520 --> 00:00:16.900] **Speaker 1**: Hello there...
[00:00:17.820 --> 00:00:20.980] **Speaker 2**: I'm going to be...
```

## Options

- `model`: Whisper model size (default: `small.en`). Options: `tiny.en`, `base.en`, `small.en`, `medium.en`, `large-v2`
- `language`: ISO language code for non-English audio (e.g., `es`, `fr`). Auto-detected if omitted.

## Important: Always post transcript in chat

When transcription completes, you MUST post the full transcript text directly in your response so it appears in the chat conversation. Do NOT just save it to a file. The transcript needs to be in the conversation context so users can discuss it and follow-up skills (like meeting analysis) can access it.

If the transcript is very long, use `send_message` to post it immediately, then summarize in your final response.

## Notes

- Transcription runs in a separate container — it may take a few minutes for long audio
- Progress is reported to the ops channel automatically
- First run downloads ML models (~2GB) which are cached for subsequent runs
- Runs on CPU (no GPU required)
