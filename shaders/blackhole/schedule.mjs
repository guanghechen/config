#!/usr/bin/env node
/**
 * Drive shader.glsl from a real active-work streak.
 *
 * State owner: this process.
 * Input: macOS HID idle time from ioreg.
 * Output: OSC 12 cursor-color trigger to Ghostty.
 *
 * Default policy:
 *   - local HID input starts/resumes a streak;
 *   - an input gap longer than idle-reset-seconds resets the streak;
 *   - after work-minutes of uninterrupted active streak, send one trigger;
 *   - next trigger requires another full interval.
 */

import { execFileSync } from 'node:child_process';
import { openSync, writeSync, closeSync } from 'node:fs';
import process from 'node:process';

const DEFAULTS = Object.freeze({
  workMinutes: 45,
  effectSeconds: 30,
  idleResetSeconds: 5 * 60,
  pollSeconds: 5,
});

const CURSOR_BASE = [0xd0, 0xa0, 0x00];
const OSC_RESET_CURSOR = '\x1b]112\x07';

class StreakState {
  activeSince = null;
  nextDueAt = null;
  lastInputSeenAt = null;
  effectUntil = 0;
  nonce = 0;
}

function usage(exitCode = 0) {
  const out = exitCode === 0 ? process.stdout : process.stderr;
  out.write(`Usage:
  schedule.mjs run [--work-minutes 45] [--idle-reset-seconds 300] [--poll-seconds 5] [--verbose]
  schedule.mjs trigger [--all-ghostty-surfaces]
  schedule.mjs off [--all-ghostty-surfaces]
  schedule.mjs status

Notes:
  run     keeps foreground state and triggers shader.glsl after active streaks.
  trigger sends one immediate test trigger.
  off     resets cursor color, hiding the effect signal.
`);
  process.exit(exitCode);
}

function parseArgs(argv) {
  const args = {
    command: argv[2],
    workMinutes: DEFAULTS.workMinutes,
    effectSeconds: DEFAULTS.effectSeconds,
    idleResetSeconds: DEFAULTS.idleResetSeconds,
    pollSeconds: DEFAULTS.pollSeconds,
    allGhosttySurfaces: false,
    verbose: false,
  };

  if (!args.command || args.command === '--help' || args.command === '-h') usage(0);
  if (!['run', 'trigger', 'off', 'status'].includes(args.command)) usage(1);

  for (let i = 3; i < argv.length; i += 1) {
    const key = argv[i];
    const readNumber = () => {
      const raw = argv[i + 1];
      if (raw === undefined) usage(1);
      i += 1;
      const value = Number(raw);
      if (!Number.isFinite(value)) usage(1);
      return value;
    };

    if (key === '--work-minutes') args.workMinutes = readNumber();
    else if (key === '--effect-seconds') args.effectSeconds = readNumber();
    else if (key === '--idle-reset-seconds') args.idleResetSeconds = readNumber();
    else if (key === '--poll-seconds') args.pollSeconds = readNumber();
    else if (key === '--all-ghostty-surfaces') args.allGhosttySurfaces = true;
    else if (key === '--verbose') args.verbose = true;
    else usage(1);
  }
  return args;
}

function hidIdleSeconds() {
  try {
    const output = execFileSync('/usr/sbin/ioreg', ['-c', 'IOHIDSystem'], {
      encoding: 'utf8',
      timeout: 1000,
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    const match = output.match(/"?HIDIdleTime"?\s*=\s*(\d+)/);
    return match ? Number(match[1]) / 1_000_000_000 : null;
  } catch {
    return null;
  }
}

function triggerSequence(nonce) {
  const loGreen = 0x1;
  const loBlue = nonce & 0xf;
  const loRed = loGreen ^ loBlue ^ 0xa;
  const rgb = [CURSOR_BASE[0] | loRed, CURSOR_BASE[1] | loGreen, CURSOR_BASE[2] | loBlue];
  return `\x1b]12;#${rgb.map((v) => v.toString(16).padStart(2, '0')).join('')}\x07`;
}

function ps(args) {
  try {
    return execFileSync('/bin/ps', args, {
      encoding: 'utf8',
      timeout: 1000,
      stdio: ['ignore', 'pipe', 'ignore'],
    });
  } catch {
    return '';
  }
}

function ghosttyPids() {
  const pids = new Set();
  for (const line of ps(['-axco', 'pid,comm']).split('\n')) {
    const match = line.trim().match(/^(\d+)\s+(.+)$/);
    if (!match || match[2].trim() !== 'ghostty') continue;
    pids.add(Number(match[1]));
  }
  return pids;
}

function ghosttyTtys() {
  const pids = ghosttyPids();
  if (pids.size === 0) return [];
  const ttys = new Set();
  for (const line of ps(['-axo', 'ppid=,tty=']).split('\n')) {
    const parts = line.trim().split(/\s+/);
    if (parts.length !== 2) continue;
    const ppid = Number(parts[0]);
    if (pids.has(ppid) && parts[1] !== '??') ttys.add(`/dev/${parts[1]}`);
  }
  return [...ttys].sort();
}

function writeSequence(path, sequence) {
  let fd = -1;
  try {
    fd = openSync(path, 'w');
    writeSync(fd, sequence);
    return true;
  } catch {
    return false;
  } finally {
    if (fd >= 0) closeSync(fd);
  }
}

function emit(sequence, allGhosttySurfaces) {
  if (allGhosttySurfaces) {
    return ghosttyTtys().filter((path) => writeSequence(path, sequence)).length;
  }
  return writeSequence('/dev/tty', sequence) ? 1 : 0;
}

function log(enabled, message) {
  if (enabled) process.stderr.write(`${message}\n`);
}

function startStreak(state, startAt, workSeconds) {
  state.activeSince = startAt;
  state.nextDueAt = startAt + workSeconds;
  state.effectUntil = 0;
}

export function updateStreak(state, now, idle, workSeconds, idleReset, verbose = false) {
  const lastInputAt = now - idle;

  if (state.lastInputSeenAt === null) {
    state.lastInputSeenAt = lastInputAt;
    if (idle < idleReset) {
      startStreak(state, now, workSeconds);
      log(verbose, 'streak started');
    }
    return;
  }

  const inputGap = lastInputAt - state.lastInputSeenAt;
  state.lastInputSeenAt = Math.max(state.lastInputSeenAt, lastInputAt);

  if (idle >= idleReset) {
    if (state.activeSince !== null) log(verbose, 'streak reset: currently idle');
    state.activeSince = null;
    state.nextDueAt = null;
    return;
  }

  if (inputGap > idleReset) {
    startStreak(state, lastInputAt, workSeconds);
    log(verbose, `streak restarted after ${inputGap.toFixed(0)}s input gap`);
    return;
  }

  if (state.activeSince === null) {
    startStreak(state, now, workSeconds);
    log(verbose, 'streak resumed');
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function run(args) {
  const workSeconds = Math.max(1, args.workMinutes * 60);
  const effectSeconds = Math.max(1, args.effectSeconds);
  const idleReset = Math.max(1, args.idleResetSeconds);
  const pollSeconds = Math.max(0.2, args.pollSeconds);
  const state = new StreakState();

  const stop = () => {
    emit(OSC_RESET_CURSOR, args.allGhosttySurfaces);
    process.exit(130);
  };
  process.once('SIGINT', stop);
  process.once('SIGTERM', stop);

  log(args.verbose, 'blackhole schedule running');
  while (true) {
    const now = Date.now() / 1000;
    const idle = hidIdleSeconds();
    if (idle === null) {
      log(args.verbose, 'HID idle unavailable; retrying');
      await sleep(pollSeconds * 1000);
      continue;
    }

    updateStreak(state, now, idle, workSeconds, idleReset, args.verbose);

    if (state.nextDueAt !== null && now >= state.nextDueAt) {
      state.nonce = (state.nonce + 1) & 0xf;
      const sent = emit(triggerSequence(state.nonce), args.allGhosttySurfaces);
      state.effectUntil = now + effectSeconds;
      state.nextDueAt = now + workSeconds;
      log(args.verbose, `trigger sent to ${sent} tty(s)`);
    }

    if (state.effectUntil && now >= state.effectUntil) {
      const sent = emit(OSC_RESET_CURSOR, args.allGhosttySurfaces);
      state.effectUntil = 0;
      log(args.verbose, `cursor reset on ${sent} tty(s)`);
    }

    await sleep(pollSeconds * 1000);
  }
}

function status() {
  const idle = hidIdleSeconds();
  if (idle === null) {
    process.stdout.write('HID idle: unavailable\n');
    return 1;
  }
  process.stdout.write(`HID idle: ${idle.toFixed(1)}s\n`);
  return 0;
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.command === 'status') process.exit(status());
  if (args.command === 'trigger') {
    const sent = emit(triggerSequence(Math.floor(Date.now() / 1000) & 0xf), args.allGhosttySurfaces);
    process.stdout.write(`trigger sent to ${sent} tty(s)\n`);
    process.exit(sent ? 0 : 1);
  }
  if (args.command === 'off') {
    const sent = emit(OSC_RESET_CURSOR, args.allGhosttySurfaces);
    process.stdout.write(`cursor reset on ${sent} tty(s)\n`);
    process.exit(sent ? 0 : 1);
  }
  await run(args);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    process.stderr.write(`${error?.stack ?? error}\n`);
    process.exit(1);
  });
}
