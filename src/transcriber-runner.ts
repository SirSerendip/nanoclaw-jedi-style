/**
 * Transcriber Runner for NanoClaw
 * Spawns the nanoclaw-transcriber container for audio-to-text transcription
 * with speaker diarization. Streams progress via callback.
 */
import { spawn } from 'child_process';
import path from 'path';

import {
  CONTAINER_HOST_GATEWAY,
  CONTAINER_RUNTIME_BIN,
  hostGatewayArgs,
} from './container-runtime.js';
import { readEnvFile } from './env.js';
import { resolveGroupFolderPath } from './group-folder.js';
import { logger } from './logger.js';

const TRANSCRIBER_IMAGE = 'nanoclaw-transcriber:latest';
const MODEL_CACHE_VOLUME = 'nanoclaw-transcriber-models';
const TRANSCRIBER_TIMEOUT_MS = 30 * 60 * 1000; // 30 minutes

export interface TranscribeRequest {
  requestId: string;
  audioPath: string; // path inside agent container (e.g. /workspace/group/audio.mp3)
  model?: string;
  language?: string;
}

export interface TranscribeResult {
  requestId: string;
  status: 'success' | 'error';
  transcript?: string;
  speakers?: number;
  words?: number;
  duration?: number;
  error?: string;
}

export async function runTranscription(
  groupFolder: string,
  request: TranscribeRequest,
  onProgress?: (percent: number, detail: string) => void,
): Promise<TranscribeResult> {
  // Resolve audio path: agent sees /workspace/group/X, host has groupDir/X
  const groupDir = resolveGroupFolderPath(groupFolder);
  const audioRelPath = request.audioPath.replace(/^\/workspace\/group\//, '');
  const hostAudioPath = path.resolve(groupDir, audioRelPath);

  // Security: ensure resolved path is within the group directory
  if (!hostAudioPath.startsWith(groupDir)) {
    return {
      requestId: request.requestId,
      status: 'error',
      error: 'Audio path escapes group directory',
    };
  }

  const hfToken =
    readEnvFile(['HUGGINGFACE_TOKEN']).HUGGINGFACE_TOKEN ||
    readEnvFile(['HF_TOKEN']).HF_TOKEN;
  if (!hfToken) {
    return {
      requestId: request.requestId,
      status: 'error',
      error:
        'HUGGINGFACE_TOKEN not set in .env — required for speaker diarization',
    };
  }

  const ext = path.extname(hostAudioPath) || '.mp3';
  const containerAudioPath = `/input/audio${ext}`;
  const containerName = `nanoclaw-transcriber-${Date.now()}`;
  const model = request.model || 'small.en';

  const args: string[] = [
    'run',
    '--rm',
    '--name',
    containerName,
    '-v',
    `${hostAudioPath}:${containerAudioPath}:ro`,
    '-v',
    `${MODEL_CACHE_VOLUME}:/models`,
    '-e',
    `HUGGINGFACE_TOKEN=${hfToken}`,
    '-e',
    'HF_HOME=/models',
    '-e',
    'TORCH_HOME=/models/torch',
    ...hostGatewayArgs(),
    TRANSCRIBER_IMAGE,
    '--audio',
    containerAudioPath,
    '--model',
    model,
    '--json',
  ];

  if (request.language) {
    args.push('--language', request.language);
  }

  logger.info(
    {
      requestId: request.requestId,
      groupFolder,
      model,
      audioPath: audioRelPath,
    },
    'Starting transcription',
  );

  return new Promise((resolve) => {
    const container = spawn(CONTAINER_RUNTIME_BIN, args, {
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';
    let lastProgressPercent = -1;

    container.stdout.on('data', (data: Buffer) => {
      stdout += data.toString();
    });

    container.stderr.on('data', (data: Buffer) => {
      const chunk = data.toString();
      stderr += chunk;
      // Parse PROGRESS lines from transcriber
      for (const line of chunk.split('\n')) {
        if (line.startsWith('PROGRESS:')) {
          try {
            const progress: { percent: number; detail: string } = JSON.parse(
              line.slice('PROGRESS:'.length),
            );
            // Deduplicate — only report when percent actually changes
            if (progress.percent !== lastProgressPercent) {
              lastProgressPercent = progress.percent;
              onProgress?.(progress.percent, progress.detail);
            }
          } catch {
            /* ignore parse errors */
          }
        }
      }
    });

    const timeout = setTimeout(() => {
      logger.error(
        { requestId: request.requestId, containerName },
        'Transcription timed out',
      );
      try {
        container.kill('SIGTERM');
      } catch {
        /* ignore */
      }
      resolve({
        requestId: request.requestId,
        status: 'error',
        error: `Transcription timed out after ${TRANSCRIBER_TIMEOUT_MS / 60000} minutes`,
      });
    }, TRANSCRIBER_TIMEOUT_MS);

    container.on('close', (code) => {
      clearTimeout(timeout);

      if (code !== 0) {
        logger.error(
          { requestId: request.requestId, code, stderr: stderr.slice(-500) },
          'Transcriber exited with error',
        );
        resolve({
          requestId: request.requestId,
          status: 'error',
          error: stderr.slice(-500) || `Transcriber exited with code ${code}`,
        });
        return;
      }

      try {
        const result = JSON.parse(stdout.trim());
        if (result.status === 'error') {
          resolve({
            requestId: request.requestId,
            status: 'error',
            error: result.error,
          });
        } else {
          logger.info(
            {
              requestId: request.requestId,
              speakers: result.speakers,
              words: result.words,
              duration: result.duration,
            },
            'Transcription complete',
          );
          resolve({
            requestId: request.requestId,
            status: 'success',
            transcript: result.transcript,
            speakers: result.speakers,
            words: result.words,
            duration: result.duration,
          });
        }
      } catch (err) {
        logger.error(
          { requestId: request.requestId, stdout: stdout.slice(-500) },
          'Failed to parse transcriber output',
        );
        resolve({
          requestId: request.requestId,
          status: 'error',
          error: 'Failed to parse transcriber output',
        });
      }
    });

    container.on('error', (err) => {
      clearTimeout(timeout);
      logger.error(
        { requestId: request.requestId, error: err },
        'Transcriber spawn error',
      );
      resolve({
        requestId: request.requestId,
        status: 'error',
        error: err.message,
      });
    });
  });
}
