---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.ai.sender" ---@type string

local S = era.m.ai
local capture = require("era.m.ai.capture")

---@class era.m.ai.sender
local M = {}

--- All durations are milliseconds. They are deliberately small; correctness comes
--- from capture-verification (when patterns are configured), not from the delays.
local STEP_DELAY = 120 ---@type integer Gap between two mode-changing keys, so <Esc> never merges with the next byte.
local SUBMIT_GAP = 150 ---@type integer Gap between the NORMAL-mode `Escape` and the submit `Enter`.
local SETTLE = 120 ---@type integer Let the TUI redraw before the first verification capture.
local VERIFY_TIMEOUT = 1500 ---@type integer Budget to confirm a footer state (insert / submitted).
local VERIFY_INTERVAL = 120 ---@type integer Between verification captures.
local IDLE_TIMEOUT = 12000 ---@type integer Budget to wait for a busy agent to go idle before sending.
local IDLE_INTERVAL = 400 ---@type integer Between idle checks.
local INSERT_TRIES = 3 ---@type integer Attempts to reach INSERT mode before giving up and pasting anyway.

---@class era.m.ai.sender.IDeliverOpts
---@field public pane_id                string
---@field public text                   string
---@field public submit                 boolean
---@field public vim_mode               boolean
---@field public insert_pattern         ?string Lua pattern; presence in the capture means the modal editor is in INSERT mode.
---@field public busy_pattern           ?string Lua pattern (per trimmed bottom line); presence means the agent is processing.

----------------------------------------------------------------------------------------------------
--- Async polling
----------------------------------------------------------------------------------------------------

---@param pane_id                       string
---@param predicate                     fun(content: string|nil): boolean
---@param timeout                       integer
---@param interval                      integer
---@param callback                      fun(ok: boolean)
---@return nil
local function poll(pane_id, predicate, timeout, interval, callback)
  local start = vim.uv.now()
  local function tick()
    S.tmux.capture(pane_id, function(content)
      if predicate(content) then
        return callback(true)
      end
      if vim.uv.now() - start >= timeout then
        return callback(false)
      end
      vim.defer_fn(tick, interval)
    end)
  end
  tick()
end

----------------------------------------------------------------------------------------------------
--- Public API
----------------------------------------------------------------------------------------------------

--- Deliver text to a tmux agent pane and (optionally) submit it.
---
--- State owner is the pane itself; this assumes a single in-flight delivery per
--- pane (no internal queue). For a modal (vim) editor it enters INSERT before
--- pasting and returns to NORMAL before submitting, with every mode-changing key
--- sent separately. When `insert_pattern` / `busy_pattern` are provided it verifies
--- each transition by capture instead of trusting fixed delays, never sends
--- `Escape` while the agent is generating (which would interrupt it), and confirms
--- the message actually left the input box. `on_done(ok, reason)` reports the
--- outcome: ok=true with reason "submitted"/"placed"/"sent", or "unverified" when
--- delivery happened but submission could not be confirmed; ok=false with
--- "not submitted"/"busy"/"insert unverified"/"paste failed"/"unsupported source".
---@param opts                          era.m.ai.sender.IDeliverOpts
---@param on_done                       ?fun(ok: boolean, reason: string)
---@return nil
function M.deliver(opts, on_done)
  local pane = opts.pane_id
  local submit = opts.submit and true or false
  local vim_mode = opts.vim_mode and true or false
  local insert_pat = opts.insert_pattern
  local busy_pat = opts.busy_pattern
  local signature = capture.make_signature(opts.text)
  local can_verify = (insert_pat ~= nil) or (busy_pat ~= nil)

  local finished = false
  local function done(ok, reason)
    if finished then
      return
    end
    finished = true
    if on_done then
      on_done(ok, reason)
    end
  end

  -- Send the submit keystrokes - NORMAL-mode Escape then Enter for a modal editor,
  -- bare Enter otherwise - then run `after` once they settle.
  local function submit_keys(after)
    if vim_mode then
      S.tmux.send_key(pane, "Escape")
      vim.defer_fn(function()
        S.tmux.send_key(pane, "Enter")
        vim.defer_fn(after, SETTLE)
      end, SUBMIT_GAP)
    else
      S.tmux.send_key(pane, "Enter")
      vim.defer_fn(after, SETTLE)
    end
  end

  -- Stage 4: confirm the message actually submitted, retrying the submit key at
  -- most once. The retry is gated on proof that the agent is idle AND our text is
  -- still pending; we never resubmit on a busy or unparseable frame (the first
  -- Enter may already have submitted and started a generation). When neither
  -- outcome can be proven we report "unverified" rather than a false "submitted".
  local function verify_submit(attempt)
    -- Require two consecutive "submitted" frames before concluding the message left
    -- the box: while pasting, the TUI can redraw the input border one frame before
    -- echoing the text, and that transient empty box must not read as a false success.
    local submitted_streak = 0
    poll(
      pane,
      function(c)
        if capture.classify(c, signature, busy_pat) == "submitted" then
          submitted_streak = submitted_streak + 1
          return submitted_streak >= 2
        end
        submitted_streak = 0
        return false
      end,
      VERIFY_TIMEOUT,
      VERIFY_INTERVAL,
      function(ok)
        if ok then
          return done(true, "submitted")
        end
        S.tmux.capture(pane, function(c)
          local state = capture.classify(c, signature, busy_pat)
          if state == "submitted" then
            return done(true, "submitted")
          end
          if state == "unknown" then
            return done(true, "unverified") -- cannot parse the screen: report honestly, send no keys
          end
          -- state == "pending": idle and provably still in the box, so resubmit once.
          if attempt >= 2 then
            return done(false, "not submitted")
          end
          submit_keys(function()
            verify_submit(attempt + 1)
          end)
        end)
      end
    )
  end

  -- Stage 3: submit. A modal editor must be in NORMAL mode for Enter to submit.
  local function do_submit()
    if not submit then
      return done(true, "placed")
    end
    submit_keys(function()
      if can_verify then
        verify_submit(1)
      else
        done(true, "sent")
      end
    end)
  end

  -- Stage 2: paste the text (lands in the box without submitting).
  local function do_paste()
    if not S.tmux.send_text(pane, opts.text) then
      return done(false, "paste failed")
    end
    vim.defer_fn(do_submit, SETTLE)
  end

  -- Stage 1: reach INSERT mode. Each attempt is Escape->i so it is idempotent
  -- (never types a literal "i") whatever the starting mode; verified when possible.
  local function ensure_insert(attempt)
    S.tmux.send_key(pane, "Escape")
    vim.defer_fn(function()
      S.tmux.send_key(pane, "i")
      vim.defer_fn(function()
        if not insert_pat then
          return do_paste()
        end
        poll(
          pane,
          function(c)
            return capture.footer_has(c, insert_pat)
          end,
          VERIFY_TIMEOUT,
          VERIFY_INTERVAL,
          function(ok)
            if ok then
              return do_paste()
            end
            -- Fail closed: with a configured insert_pattern we must never paste into
            -- an unconfirmed modal editor, where the text could be read as NORMAL-mode
            -- commands. Report "insert unverified" instead of risking the buffer.
            if attempt >= INSERT_TRIES then
              return done(false, "insert unverified")
            end
            ensure_insert(attempt + 1)
          end
        )
      end, SETTLE)
    end, STEP_DELAY)
  end

  local function start()
    if vim_mode then
      ensure_insert(1)
    else
      do_paste()
    end
  end

  -- Stage 0: never drive the editor while the agent is generating (Escape would
  -- interrupt it). Wait for idle when we can detect it; otherwise proceed.
  if busy_pat then
    poll(
      pane,
      function(c)
        return c ~= nil and not capture.footer_has(c, busy_pat)
      end,
      IDLE_TIMEOUT,
      IDLE_INTERVAL,
      function(idle)
        if not idle then
          return done(false, "busy")
        end
        start()
      end
    )
  else
    start()
  end
end

return M
