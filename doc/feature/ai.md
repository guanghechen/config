# AI Widget

A custom implementation replacing sidekick.nvim for AI agent CLI integration.

## Supported Agents

- claude (Claude Code)
- codex (OpenAI Codex)
- copilot (GitHub Copilot CLI)
- gemini (Google Gemini CLI)

## Supported Backends

- **tmux**: Primary backend for terminal multiplexing
- **Native neovim terminal**: Fallback when tmux is unavailable

Note: zellij is explicitly not supported.

## Core Features

### 1. Attach Command

Opens a "Select CLI tool" picker with the following structure:

**Picker Items (in order):**
1. Already attached sources (highlighted with brightGreen + bold)
2. Running agent panes from tmux (brightBlue)
3. New agent options for creation (fg2)

**Sorting Rules:**
- Attached sources appear first (as a separate group)
- Running panes appear next (as a separate group):
  - Same session as current tmux session comes first
  - Within same session, same window comes first
  - Then sorted alphabetically by session name → window name → pane id
- New agent options appear last, sorted alphabetically by agent name
- If an agent already has a running session for current cwd, don't show it in new options

**Selection Behavior:**
- If selecting an existing external pane (session name doesn't match `<agent>-<hex_hash>` pattern with correct hash length):
  - Only record the pane identifier, no neovim terminal opened
  - Messages sent via tmux directly
- If selecting an existing agent session pane:
  - Open a neovim terminal and attach to the pane
- If selecting to create new:
  - Check if session already exists for (agent, cwd)
  - If exists: attach to it
  - If not: create new session, then attach

### 2. Multi-Source Support

- Can attach to multiple sources simultaneously
- When sending with multiple attached sources:
  - Shows picker to select target(s)
  - Supports multi-select (Tab to toggle)
  - "Send to all" option at top when multiple sources attached

### 3. Prompts

Built-in prompts with render function that returns the actual content:
- `diagnostics`: Fix diagnostics in current file (requires: file + diagnostics)
- `diagnostics_all`: Fix all diagnostics (requires: diagnostics in any buffer)
- `ask`: General question about target (requires: selection or file)
- `explain`: Explain target code (requires: selection or file)
- `fix`: Fix target code (requires: selection or file)
- `optimize`: Optimize target code (requires: selection or file)
- `refactor`: Refactor target code (requires: selection or file)
- `review`: Review target code (requires: selection or file)
- `review_changes`: Review git changes (requires: git changes)
- `test`: Write tests for target (requires: selection or file)

Each prompt has a `render(ctx)` function that returns:
- `{ text, header_end }` when all required context is available
- `nil` when the prompt is not available (missing required context)

**Target Resolution:**
- If visual selection exists: uses selection range (e.g., `@filepath :L1:C1-L10:C20`)
- Otherwise: falls back to current file (e.g., `@filepath`)

**Preview Highlighting:**
- Header lines (up to `header_end`) are highlighted with `f_us_ai_prompt_header`

### 4. Notifications

- Success/failure feedback for all message sends
- Attach/detach notifications

## Implementation Structure

```
lua/eve/ux/widget/ai/
├── init.lua      # Module entry
├── action.lua    # Core actions (attach, detach, send)
├── config.lua    # Agent configs
├── picker.lua    # Picker UI for attach/detach/send target
├── proc.lua      # Process detection for running agents
├── prompt.lua    # Prompt definitions and context helpers
├── state.lua     # Attached sources state management
├── term.lua      # Neovim terminal management
├── tmux.lua      # Tmux operations (list, create, send)
└── types.lua     # Type definitions
```

## Commands

Registered in `lua/era/command.lua`:
- `ai.attach_agent`: Open attach picker
- `ai.detach_agent`: Detach agent (direct detach if only one attached, otherwise show picker)
- `ai.submit_buffer`: Send current split block content and submit
- `ai.submit_selection`: Send selection and submit
- `ai.send_buffer`: Send entire buffer content (no submit)
- `ai.send_selection`: Send selection (no submit)
- `ai.send_this`: Send current file path
- `ai.send_file`: Send current file content and submit
- `ai.select_prompt`: Open prompt picker
- `ai.edit`: Edit with AI context

### Detach Behavior

- When detaching a tmux source with an attached neovim terminal, the terminal is automatically closed
- If only one agent is attached, detach happens immediately without showing picker

## Statusline Component

`lua/eve/ux/nvimbar/component/ai.lua`:
- Shows attached agent count and names
- Clickable to open detach picker
- Uses `{position}_ai_status_icon` and `{position}_ai_status_text` highlight groups (e.g., `sl_ai_status_icon`)

## Highlight Groups

Defined in `lua/eve/constant/hlgroup/widget.lua`:
- `f_us_ai_attached`: brightGreen, bold (attached items)
- `f_us_ai_new`: fg2 (create new options)
- `f_us_ai_prompt_header`: purple, bold (prompt preview header)
- `f_us_ai_running`: brightBlue (running but not attached)
- `f_us_ai_send_to_all`: pink, bold (send to all option)

## Tmux Structure

Session: `<agent>-<cwd_hash>` (e.g., `claude-a1b2c3d4e5f6`, `codex-9f8e7d6c5b4a`)
- One session per (agent, cwd) combination
- Hash length: `16 - len(agent)` hex characters from MD5 of cwd
- Session name validation uses strict pattern matching: `^<agent>-[0-9a-f]{hash_len}$`
