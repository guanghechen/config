---
name: tmux
description: >-
  Use when the user asks for raw tmux pane operations in an explicit pane ref
  (%N, #N, or @M#N): inspect, type, send keys, paste, or run commands. Choose
  by intent, not by what is running in the pane; raw operations on an agent pane
  still use this skill. For structured agent-to-agent messages, use
  tmux-cowork instead. Never guess, scan for, or auto-select panes.
argument-hint: "<pane-ref> [inspect | keys | command | paste]"
---

# Tmux

Operate an explicitly specified tmux pane at the raw terminal level. The target may be a shell, editor, REPL, TUI, or even an agent pane when the user asks for raw pane operation rather than structured collaboration.

## When To Use

Use this skill only when all conditions are met:

- The user asks to inspect, operate, type into, send keys, run a command, or paste into a tmux pane.
- The user provides an explicit pane ref: `%N`, `#N`, or `@M#N`.
- The task is a raw pane operation, not a structured agent-to-agent message. Use `tmux-cowork` only for structured messages.

If no pane ref is provided, stop and ask for one. Never guess, scan for, or auto-select panes.

## Pane Ref

| ref    | target |
|--------|--------|
| `%3`   | `%3`   |
| `#2`   | `:.2`  |
| `@1#2` | `@1.2` |

Use `$TMUX_PANE` to locate this agent's own pane. Never use bare `tmux display-message -p '#{pane_id}'`; it returns the focused client's active pane.

## Workflow

1. Convert the pane ref to a tmux target.
2. Capture the target pane first; establish its current state and context.
3. Classify the operation: inspect, send keys, run shell command, paste text, or navigate editor/TUI.
4. Perform the smallest necessary action.
5. Re-capture after the action; confirm the result or state the uncertainty.

## Inspect

```bash
tmux capture-pane -ep -t '<target>' | tail -80
```

Read only the pane content needed for the task. If the pane shows secrets, credentials, tokens, private keys, or `.env*` content, do not repeat it; stop and ask the user how to proceed.

## Send Keys

Send ordinary keys:

```bash
tmux send-keys -t '<target>' <key> [<key> ...]
```

Send short text without submitting. Prefer `-l` (literal) so the text is never reinterpreted as key names or control sequences:

```bash
tmux send-keys -l -t '<target>' '<text>'
```

Before sending text into an agent/editor pane, confirm its input mode first (see "Editor / TUI Safety") — a Vim-mode composer in NORMAL runs your text as commands.

Send `Enter` only when the user asked to submit, or when you have confirmed the target is an idle shell prompt and the text is intended as a command. After a multiline buffer, one `Enter` may not submit — re-capture and, if not submitted, send the submit key again (bounded retry).

## Run Shell Commands

Submit a shell command only when the target pane is clearly an idle shell prompt:

```bash
tmux send-keys -t '<target>' '<command>' Enter
```

If you cannot confirm the pane is an idle shell prompt, do not submit the command. Inspect again or ask the user.

Confirm with the user before running a command that is destructive, writes files, deletes data, installs packages, pushes to a remote, terminates processes, or affects external systems, unless the user already authorized that specific operation.

## Paste Text

Use a tmux buffer for multiline text or content containing shell-special characters:

```bash
tmp=$(mktemp /tmp/tmux-pane.XXXXXX)
cat > "$tmp" <<'MSG'
<text>
MSG
tmux load-buffer "$tmp"
tmux paste-buffer -t '<target>'
rm -f "$tmp"
```

Paste does not mean submit. Whether to send `Enter` depends on the target state and the user's intent.

## Editor / TUI Safety

- Capture before acting; identify the mode before sending `Enter`, `Escape`, or control keys.
- Vim-mode agent composer (e.g. Claude Code): in NORMAL (block cursor, no `-- INSERT --`) text is run as commands, so send `i` to reach INSERT before typing; `Enter` submits from any mode, so do not send `Escape` first (unnecessary, interrupts a busy agent).
- Real editor (vim/nvim): in insert `Enter` is a newline; submit/leave via `Escape` then the editor's command — do not treat it like an agent composer.
- Non-modal target (shell, Codex): type directly; never send `Escape`/`i`.
- For a running TUI, REPL, or long-running command, do not type shell commands into the pane unless a prompt/input field is clearly active.

## Hard Stop Rules

- Never guess, scan for, or auto-select panes.
- Do not upgrade ordinary pane operations into `tmux-cowork`.
- Do not send secrets, credentials, `.env*` content, or sensitive logs.
- Do not submit text when the target state is unclear; capture first and state the uncertainty.
- Do not claim success unless a re-capture shows a clear result.
- Suspected Vim-mode composer: confirm INSERT before sending text, and the text intact before `Enter`, or it is run as commands / submitted broken. (Confirmed non-modal prompts are exempt.)
