// Hooks run synchronously in each thread. A model request opens its turn before
// any tool can wait; terminal events close it. Other events must match that turn.
// Tool identities keep an old answer or cancellation from clearing newer waits.
export function advanceProgress(state, name, event) {
  if (name === "SessionStart") return event.source === "compact" ? state : { threads: {}, controls: {} }

  const next = structuredClone(state)
  const threadId = event.agent_id ?? "main"
  const thread = next.threads[threadId]
  const call = JSON.stringify([threadId, event.turn_id, event.tool_use_id])

  if (name === "SessionEnd") {
    for (const thread of Object.values(next.threads)) endTurn(thread)
    next.controls = {}
    next.ended = true
    return next
  }
  if (next.ended) return next

  if (name === "UserPromptSubmit" || name === "PreModelRequest") {
    next.threads[threadId] = { turnId: event.turn_id, permission: false, questions: [], closed: false }
    // Failed or cancelled control calls have no PostToolUse; discard their snapshots
    // once the caller moves on without treating them as successful cancellations.
    for (const [key, control] of Object.entries(next.controls)) {
      if (control.caller === threadId) delete next.controls[key]
    }
    return next
  }

  if (!thread || thread.turnId !== event.turn_id) return next
  // Stop hooks can still be running when the user interrupts this same turn.
  if (thread.closed && name !== "Interrupt") return next

  switch (name) {
    case "PermissionRequest":
      thread.permission = true
      break
    case "PreToolUse":
      if (!event.tool_use_id) break
      if (event.tool_name === "request_user_input") {
        if (!thread.questions.includes(event.tool_use_id)) thread.questions.push(event.tool_use_id)
      } else if (isInterruptingInput(event)) {
        const target = event.tool_input.target
        const child = next.threads[target]
        if (child) next.controls[call] = { caller: threadId, target, turnId: child.turnId }
      }
      break
    case "PostToolUse":
      if (event.tool_name === "request_user_input") {
        thread.questions = thread.questions.filter((id) => id !== event.tool_use_id)
      } else if (event.tool_name === "multi_agent_v1close_agent") {
        // A successful close shuts down the child itself. It may have started or
        // advanced turns after PreToolUse; the actual target comes from PostToolUse.
        const child = next.threads[event.tool_input?.target]
        if (child) endTurn(child)
      } else if (isInterruptingInput(event)) {
        // PostToolUse is emitted only for successful calls. send_input may already
        // have started a new child turn, which must survive this old cancellation.
        const control = next.controls[call]
        const child = control && next.threads[control.target]
        if (child && child.turnId === control.turnId) endTurn(child)
        delete next.controls[call]
      }
      break
    case "Stop":
    case "SubagentStop":
      endTurn(thread)
      break
    case "Interrupt":
      // Interrupt is root-only. Its turn check above protects a newer root turn.
      for (const thread of Object.values(next.threads)) endTurn(thread)
      next.controls = {}
      break
  }
  return next
}

export function isWaiting(state) {
  return Object.values(state.threads).some((thread) => thread.permission || thread.questions.length > 0)
}

function endTurn(thread) {
  thread.permission = false
  thread.questions = []
  thread.closed = true
}

function isInterruptingInput(event) {
  // CLI 0.169.0 flattens non-default tool namespaces without a separator.
  return event.tool_name === "multi_agent_v1send_input"
    && event.tool_input?.interrupt === true
    && typeof event.tool_input.target === "string"
}
