import fs from 'fs';
import path from 'path';

import { CronExpressionParser } from 'cron-parser';

import { DATA_DIR, GROUPS_DIR, IPC_POLL_INTERVAL, TIMEZONE } from './config.js';
import { AvailableGroup } from './container-runner.js';
import { createTask, deleteTask, getTaskById, updateTask } from './db.js';
import { isValidGroupFolder, resolveGroupIpcPath } from './group-folder.js';
import { logger } from './logger.js';
import { runTranscription, TranscribeRequest } from './transcriber-runner.js';
import { RegisteredGroup } from './types.js';
import { execFile } from 'child_process';

export interface IpcDeps {
  sendMessage: (jid: string, text: string) => Promise<void>;
  registeredGroups: () => Record<string, RegisteredGroup>;
  registerGroup: (jid: string, group: RegisteredGroup) => void;
  syncGroups: (force: boolean) => Promise<void>;
  getAvailableGroups: () => AvailableGroup[];
  writeGroupsSnapshot: (
    groupFolder: string,
    isMain: boolean,
    availableGroups: AvailableGroup[],
    registeredJids: Set<string>,
  ) => void;
  onTasksChanged: () => void;
  notifyOps: (text: string) => Promise<void>;
}

let ipcWatcherRunning = false;

export function startIpcWatcher(deps: IpcDeps): void {
  if (ipcWatcherRunning) {
    logger.debug('IPC watcher already running, skipping duplicate start');
    return;
  }
  ipcWatcherRunning = true;

  const ipcBaseDir = path.join(DATA_DIR, 'ipc');
  fs.mkdirSync(ipcBaseDir, { recursive: true });

  const processIpcFiles = async () => {
    // Scan all group IPC directories (identity determined by directory)
    let groupFolders: string[];
    try {
      groupFolders = fs.readdirSync(ipcBaseDir).filter((f) => {
        const stat = fs.statSync(path.join(ipcBaseDir, f));
        return stat.isDirectory() && f !== 'errors';
      });
    } catch (err) {
      logger.error({ err }, 'Error reading IPC base directory');
      setTimeout(processIpcFiles, IPC_POLL_INTERVAL);
      return;
    }

    const registeredGroups = deps.registeredGroups();

    // Build folder→isMain lookup from registered groups
    const folderIsMain = new Map<string, boolean>();
    for (const group of Object.values(registeredGroups)) {
      if (group.isMain) folderIsMain.set(group.folder, true);
    }

    for (const sourceGroup of groupFolders) {
      const isMain = folderIsMain.get(sourceGroup) === true;
      const messagesDir = path.join(ipcBaseDir, sourceGroup, 'messages');
      const tasksDir = path.join(ipcBaseDir, sourceGroup, 'tasks');

      // Process messages from this group's IPC directory
      try {
        if (fs.existsSync(messagesDir)) {
          const messageFiles = fs
            .readdirSync(messagesDir)
            .filter((f) => f.endsWith('.json'));
          for (const file of messageFiles) {
            const filePath = path.join(messagesDir, file);
            try {
              const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
              if (data.type === 'message' && data.chatJid && data.text) {
                // Authorization: verify this group can send to this chatJid
                const targetGroup = registeredGroups[data.chatJid];
                if (
                  isMain ||
                  (targetGroup && targetGroup.folder === sourceGroup)
                ) {
                  await deps.sendMessage(data.chatJid, data.text);
                  logger.info(
                    { chatJid: data.chatJid, sourceGroup },
                    'IPC message sent',
                  );
                } else {
                  logger.warn(
                    { chatJid: data.chatJid, sourceGroup },
                    'Unauthorized IPC message attempt blocked',
                  );
                }
              }
              fs.unlinkSync(filePath);
            } catch (err) {
              logger.error(
                { file, sourceGroup, err },
                'Error processing IPC message',
              );
              const errorDir = path.join(ipcBaseDir, 'errors');
              fs.mkdirSync(errorDir, { recursive: true });
              fs.renameSync(
                filePath,
                path.join(errorDir, `${sourceGroup}-${file}`),
              );
            }
          }
        }
      } catch (err) {
        logger.error(
          { err, sourceGroup },
          'Error reading IPC messages directory',
        );
      }

      // Process tasks from this group's IPC directory
      try {
        if (fs.existsSync(tasksDir)) {
          const taskFiles = fs
            .readdirSync(tasksDir)
            .filter((f) => f.endsWith('.json'));
          for (const file of taskFiles) {
            const filePath = path.join(tasksDir, file);
            try {
              const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
              // Pass source group identity to processTaskIpc for authorization
              await processTaskIpc(data, sourceGroup, isMain, deps);
              fs.unlinkSync(filePath);
            } catch (err) {
              logger.error(
                { file, sourceGroup, err },
                'Error processing IPC task',
              );
              const errorDir = path.join(ipcBaseDir, 'errors');
              fs.mkdirSync(errorDir, { recursive: true });
              fs.renameSync(
                filePath,
                path.join(errorDir, `${sourceGroup}-${file}`),
              );
            }
          }
        }
      } catch (err) {
        logger.error({ err, sourceGroup }, 'Error reading IPC tasks directory');
      }

      // Process transcription requests from this group's IPC directory
      const transcribeDir = path.join(ipcBaseDir, sourceGroup, 'transcribe');
      try {
        if (fs.existsSync(transcribeDir)) {
          const requestFiles = fs
            .readdirSync(transcribeDir)
            .filter(
              (f) =>
                f.endsWith('.json') &&
                !f.startsWith('result-') &&
                !f.startsWith('progress-'),
            );
          for (const file of requestFiles) {
            const filePath = path.join(transcribeDir, file);
            try {
              const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
              fs.unlinkSync(filePath);

              if (
                data.type === 'transcribe_audio' &&
                data.requestId &&
                data.audioPath
              ) {
                // Fire-and-forget — transcription runs in background
                processTranscribeRequest(
                  sourceGroup,
                  data as TranscribeRequest & { type: string },
                  transcribeDir,
                  deps,
                ).catch((err) =>
                  logger.error(
                    { err, requestId: data.requestId },
                    'Transcription handler error',
                  ),
                );
              }
            } catch (err) {
              logger.error(
                { file, sourceGroup, err },
                'Error processing transcription request',
              );
            }
          }
        }
      } catch (err) {
        logger.error(
          { err, sourceGroup },
          'Error reading IPC transcribe directory',
        );
      }

      // Process library ingestion requests from this group's IPC directory
      const libraryDir = path.join(ipcBaseDir, sourceGroup, 'library');
      try {
        if (fs.existsSync(libraryDir)) {
          const requestFiles = fs
            .readdirSync(libraryDir)
            .filter((f) => f.endsWith('.json') && !f.startsWith('result-'));
          for (const file of requestFiles) {
            const filePath = path.join(libraryDir, file);
            try {
              const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
              fs.unlinkSync(filePath);

              if (
                data.type === 'library_ingest' &&
                data.requestId &&
                data.content &&
                data.filename &&
                data.category
              ) {
                // Fire-and-forget — ingestion runs in background
                processLibraryIngest(sourceGroup, data, libraryDir, deps).catch(
                  (err) =>
                    logger.error(
                      { err, requestId: data.requestId },
                      'Library ingestion handler error',
                    ),
                );
              }
            } catch (err) {
              logger.error(
                { file, sourceGroup, err },
                'Error processing library ingest request',
              );
            }
          }
        }
      } catch (err) {
        logger.error(
          { err, sourceGroup },
          'Error reading IPC library directory',
        );
      }

      // Relay pipeline progress updates to ops channel
      const progressDir = path.join(ipcBaseDir, sourceGroup, 'progress');
      try {
        if (fs.existsSync(progressDir)) {
          const progressFiles = fs
            .readdirSync(progressDir)
            .filter((f) => f.endsWith('.json'));
          for (const file of progressFiles) {
            const filePath = path.join(progressDir, file);
            try {
              const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
              fs.unlinkSync(filePath);
              if (data.message) {
                deps.notifyOps(data.message);
              }
            } catch (err) {
              logger.error(
                { file, sourceGroup, err },
                'Error processing progress update',
              );
            }
          }
        }
      } catch (err) {
        logger.error(
          { err, sourceGroup },
          'Error reading IPC progress directory',
        );
      }
    }

    setTimeout(processIpcFiles, IPC_POLL_INTERVAL);
  };

  processIpcFiles();
  logger.info('IPC watcher started (per-group namespaces)');
}

export async function processTaskIpc(
  data: {
    type: string;
    taskId?: string;
    prompt?: string;
    schedule_type?: string;
    schedule_value?: string;
    context_mode?: string;
    script?: string;
    groupFolder?: string;
    chatJid?: string;
    targetJid?: string;
    // For register_group
    jid?: string;
    name?: string;
    folder?: string;
    trigger?: string;
    requiresTrigger?: boolean;
    containerConfig?: RegisteredGroup['containerConfig'];
  },
  sourceGroup: string, // Verified identity from IPC directory
  isMain: boolean, // Verified from directory path
  deps: IpcDeps,
): Promise<void> {
  const registeredGroups = deps.registeredGroups();

  switch (data.type) {
    case 'schedule_task':
      if (
        data.prompt &&
        data.schedule_type &&
        data.schedule_value &&
        data.targetJid
      ) {
        // Resolve the target group from JID
        const targetJid = data.targetJid as string;
        const targetGroupEntry = registeredGroups[targetJid];

        if (!targetGroupEntry) {
          logger.warn(
            { targetJid },
            'Cannot schedule task: target group not registered',
          );
          break;
        }

        const targetFolder = targetGroupEntry.folder;

        // Authorization: non-main groups can only schedule for themselves
        if (!isMain && targetFolder !== sourceGroup) {
          logger.warn(
            { sourceGroup, targetFolder },
            'Unauthorized schedule_task attempt blocked',
          );
          break;
        }

        const scheduleType = data.schedule_type as 'cron' | 'interval' | 'once';

        let nextRun: string | null = null;
        if (scheduleType === 'cron') {
          try {
            const interval = CronExpressionParser.parse(data.schedule_value, {
              tz: TIMEZONE,
            });
            nextRun = interval.next().toISOString();
          } catch {
            logger.warn(
              { scheduleValue: data.schedule_value },
              'Invalid cron expression',
            );
            break;
          }
        } else if (scheduleType === 'interval') {
          const ms = parseInt(data.schedule_value, 10);
          if (isNaN(ms) || ms <= 0) {
            logger.warn(
              { scheduleValue: data.schedule_value },
              'Invalid interval',
            );
            break;
          }
          nextRun = new Date(Date.now() + ms).toISOString();
        } else if (scheduleType === 'once') {
          const date = new Date(data.schedule_value);
          if (isNaN(date.getTime())) {
            logger.warn(
              { scheduleValue: data.schedule_value },
              'Invalid timestamp',
            );
            break;
          }
          nextRun = date.toISOString();
        }

        const taskId =
          data.taskId ||
          `task-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
        const contextMode =
          data.context_mode === 'group' || data.context_mode === 'isolated'
            ? data.context_mode
            : 'isolated';
        createTask({
          id: taskId,
          group_folder: targetFolder,
          chat_jid: targetJid,
          prompt: data.prompt,
          script: data.script || null,
          schedule_type: scheduleType,
          schedule_value: data.schedule_value,
          context_mode: contextMode,
          next_run: nextRun,
          status: 'active',
          created_at: new Date().toISOString(),
        });
        logger.info(
          { taskId, sourceGroup, targetFolder, contextMode },
          'Task created via IPC',
        );
        deps.onTasksChanged();
      }
      break;

    case 'pause_task':
      if (data.taskId) {
        const task = getTaskById(data.taskId);
        if (task && (isMain || task.group_folder === sourceGroup)) {
          updateTask(data.taskId, { status: 'paused' });
          logger.info(
            { taskId: data.taskId, sourceGroup },
            'Task paused via IPC',
          );
          deps.onTasksChanged();
        } else {
          logger.warn(
            { taskId: data.taskId, sourceGroup },
            'Unauthorized task pause attempt',
          );
        }
      }
      break;

    case 'resume_task':
      if (data.taskId) {
        const task = getTaskById(data.taskId);
        if (task && (isMain || task.group_folder === sourceGroup)) {
          updateTask(data.taskId, { status: 'active' });
          logger.info(
            { taskId: data.taskId, sourceGroup },
            'Task resumed via IPC',
          );
          deps.onTasksChanged();
        } else {
          logger.warn(
            { taskId: data.taskId, sourceGroup },
            'Unauthorized task resume attempt',
          );
        }
      }
      break;

    case 'cancel_task':
      if (data.taskId) {
        const task = getTaskById(data.taskId);
        if (task && (isMain || task.group_folder === sourceGroup)) {
          deleteTask(data.taskId);
          logger.info(
            { taskId: data.taskId, sourceGroup },
            'Task cancelled via IPC',
          );
          deps.onTasksChanged();
        } else {
          logger.warn(
            { taskId: data.taskId, sourceGroup },
            'Unauthorized task cancel attempt',
          );
        }
      }
      break;

    case 'update_task':
      if (data.taskId) {
        const task = getTaskById(data.taskId);
        if (!task) {
          logger.warn(
            { taskId: data.taskId, sourceGroup },
            'Task not found for update',
          );
          break;
        }
        if (!isMain && task.group_folder !== sourceGroup) {
          logger.warn(
            { taskId: data.taskId, sourceGroup },
            'Unauthorized task update attempt',
          );
          break;
        }

        const updates: Parameters<typeof updateTask>[1] = {};
        if (data.prompt !== undefined) updates.prompt = data.prompt;
        if (data.script !== undefined) updates.script = data.script || null;
        if (data.schedule_type !== undefined)
          updates.schedule_type = data.schedule_type as
            | 'cron'
            | 'interval'
            | 'once';
        if (data.schedule_value !== undefined)
          updates.schedule_value = data.schedule_value;

        // Recompute next_run if schedule changed
        if (data.schedule_type || data.schedule_value) {
          const updatedTask = {
            ...task,
            ...updates,
          };
          if (updatedTask.schedule_type === 'cron') {
            try {
              const interval = CronExpressionParser.parse(
                updatedTask.schedule_value,
                { tz: TIMEZONE },
              );
              updates.next_run = interval.next().toISOString();
            } catch {
              logger.warn(
                { taskId: data.taskId, value: updatedTask.schedule_value },
                'Invalid cron in task update',
              );
              break;
            }
          } else if (updatedTask.schedule_type === 'interval') {
            const ms = parseInt(updatedTask.schedule_value, 10);
            if (!isNaN(ms) && ms > 0) {
              updates.next_run = new Date(Date.now() + ms).toISOString();
            }
          }
        }

        updateTask(data.taskId, updates);
        logger.info(
          { taskId: data.taskId, sourceGroup, updates },
          'Task updated via IPC',
        );
        deps.onTasksChanged();
      }
      break;

    case 'refresh_groups':
      // Only main group can request a refresh
      if (isMain) {
        logger.info(
          { sourceGroup },
          'Group metadata refresh requested via IPC',
        );
        await deps.syncGroups(true);
        // Write updated snapshot immediately
        const availableGroups = deps.getAvailableGroups();
        deps.writeGroupsSnapshot(
          sourceGroup,
          true,
          availableGroups,
          new Set(Object.keys(registeredGroups)),
        );
      } else {
        logger.warn(
          { sourceGroup },
          'Unauthorized refresh_groups attempt blocked',
        );
      }
      break;

    case 'register_group':
      // Only main group can register new groups
      if (!isMain) {
        logger.warn(
          { sourceGroup },
          'Unauthorized register_group attempt blocked',
        );
        break;
      }
      if (data.jid && data.name && data.folder && data.trigger) {
        if (!isValidGroupFolder(data.folder)) {
          logger.warn(
            { sourceGroup, folder: data.folder },
            'Invalid register_group request - unsafe folder name',
          );
          break;
        }
        // Defense in depth: agent cannot set isMain via IPC.
        // Preserve isMain from the existing registration so IPC config
        // updates (e.g. adding additionalMounts) don't strip the flag.
        const existingGroup = registeredGroups[data.jid];
        deps.registerGroup(data.jid, {
          name: data.name,
          folder: data.folder,
          trigger: data.trigger,
          added_at: new Date().toISOString(),
          containerConfig: data.containerConfig,
          requiresTrigger: data.requiresTrigger,
          isMain: existingGroup?.isMain,
        });
      } else {
        logger.warn(
          { data },
          'Invalid register_group request - missing required fields',
        );
      }
      break;

    default:
      logger.warn({ type: data.type }, 'Unknown IPC task type');
  }
}

/**
 * Build a progress bar for transcription ops notifications.
 */
function transcriptionMeter(percent: number): string {
  const filled = Math.min(10, Math.round(percent / 10));
  const empty = 10 - filled;
  return '█'.repeat(filled) + '░'.repeat(empty);
}

/**
 * Handle a transcription request from the agent.
 * Spawns the transcriber container, streams progress to ops,
 * and writes the result back to IPC for the agent to pick up.
 */
async function processTranscribeRequest(
  groupFolder: string,
  request: TranscribeRequest & { type: string },
  transcribeDir: string,
  deps: IpcDeps,
): Promise<void> {
  const { requestId, audioPath } = request;
  const audioName = path.basename(audioPath);

  deps.notifyOps(`📝 Transcription started — ${audioName}`);

  let lastReportedPct = -1;

  const result = await runTranscription(
    groupFolder,
    request,
    (percent, detail) => {
      // Report to ops at meaningful intervals (every ~10% or phase change)
      const shouldReport =
        percent >= lastReportedPct + 10 ||
        percent === 100 ||
        (percent === 50 && lastReportedPct < 50) || // whisper → diarization boundary
        (percent === 90 && lastReportedPct < 90); // diarization → merge boundary

      if (shouldReport) {
        lastReportedPct = percent;
        deps.notifyOps(
          `📝 ${transcriptionMeter(percent)} ${percent}% — ${detail}`,
        );
      }
    },
  );

  // Write result for agent MCP tool to pick up
  const resultPath = path.join(transcribeDir, `result-${requestId}.json`);
  const tempPath = `${resultPath}.tmp`;
  fs.writeFileSync(tempPath, JSON.stringify(result, null, 2));
  fs.renameSync(tempPath, resultPath);

  if (result.status === 'success') {
    const dur = result.duration
      ? `${Math.floor(result.duration / 60)}m ${Math.round(result.duration % 60)}s`
      : 'unknown duration';
    deps.notifyOps(
      `📝 ██████████ 100% — Transcription complete (${result.speakers} speakers, ${result.words} words, ${dur})`,
    );
  } else {
    deps.notifyOps(
      `📝 ❌ Transcription failed — ${result.error?.slice(0, 200) || 'unknown error'}`,
    );
  }
}

// ── Library ingestion ─────────────────────────────────────────────────────

/** JOTF channels allowed to ingest into the shared library. */
const JOTF_LIBRARY_GROUPS = new Set([
  'slack_main',
  'slack_meetos',
  'slack_random',
  'main',
]);

interface LibraryIngestRequest {
  type: 'library_ingest';
  requestId: string;
  content: string;
  filename: string;
  category: string;
  tags?: string;
  author?: string;
  contentDate?: string;
  originChannel?: string;
}

/**
 * Process a library ingestion request from a container agent.
 * Writes the content to the shared library sources directory,
 * runs the ingestion script, and writes a result file back to IPC.
 */
async function processLibraryIngest(
  groupFolder: string,
  request: LibraryIngestRequest,
  libraryIpcDir: string,
  deps: IpcDeps,
): Promise<void> {
  const { requestId, content, filename, category, tags, author, contentDate } =
    request;
  const originChannel = request.originChannel || groupFolder;

  // Authorization: only JOTF channels can ingest
  if (!JOTF_LIBRARY_GROUPS.has(groupFolder)) {
    logger.warn(
      { groupFolder, requestId },
      'Non-JOTF group attempted library ingestion — blocked',
    );
    writeLibraryResult(libraryIpcDir, requestId, {
      status: 'error',
      error: 'Library ingestion is restricted to JOTF business channels.',
    });
    return;
  }

  deps.notifyOps(`📚 Library ingest — "${filename}" from ${groupFolder}`);

  const libraryDir = path.join(GROUPS_DIR, 'global', 'library');
  const sourcesDir = path.join(libraryDir, 'sources');
  const categoryDir = path.join(sourcesDir, category);

  // Ensure category directory exists
  fs.mkdirSync(categoryDir, { recursive: true });

  // Build markdown with frontmatter
  const frontmatter = [
    '---',
    `origin_channel: ${originChannel}`,
    author ? `author: ${author}` : null,
    contentDate ? `contentDate: ${contentDate}` : null,
    tags ? `tags: ${tags}` : null,
    '---',
  ]
    .filter(Boolean)
    .join('\n');

  const safeName = filename.replace(/[^a-zA-Z0-9._-]/g, '-');
  const filePath = path.join(categoryDir, safeName);
  const fileContent = `${frontmatter}\n\n${content}`;

  try {
    fs.writeFileSync(filePath, fileContent, 'utf-8');

    // Run ingestion script
    const relFile = path.relative(sourcesDir, filePath);
    const ingestScript = path.join(libraryDir, 'ingest.mjs');

    await new Promise<void>((resolve, reject) => {
      execFile(
        process.execPath,
        [ingestScript, '--file', `sources/${relFile}`],
        { cwd: libraryDir, timeout: 120_000 },
        (error, stdout, stderr) => {
          if (stdout)
            logger.info({ stdout: stdout.trim() }, 'Library ingest output');
          if (stderr)
            logger.warn({ stderr: stderr.trim() }, 'Library ingest stderr');
          if (error) {
            reject(error);
          } else {
            resolve();
          }
        },
      );
    });

    writeLibraryResult(libraryIpcDir, requestId, {
      status: 'success',
      filename: safeName,
      category,
      message: `Ingested "${safeName}" into the shared library.`,
    });

    deps.notifyOps(`📚 Library ingest complete — "${safeName}" [${category}]`);
  } catch (err) {
    const errorMsg =
      err instanceof Error ? err.message : 'Unknown ingestion error';
    logger.error({ err, requestId }, 'Library ingestion failed');

    writeLibraryResult(libraryIpcDir, requestId, {
      status: 'error',
      error: errorMsg,
    });

    deps.notifyOps(`📚 ❌ Library ingest failed — ${errorMsg.slice(0, 200)}`);
  }
}

function writeLibraryResult(
  libraryIpcDir: string,
  requestId: string,
  result: Record<string, unknown>,
): void {
  const resultPath = path.join(libraryIpcDir, `result-${requestId}.json`);
  const tempPath = `${resultPath}.tmp`;
  fs.writeFileSync(tempPath, JSON.stringify(result, null, 2));
  fs.renameSync(tempPath, resultPath);
}
