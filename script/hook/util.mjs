export function allow() {
  // Codex treats empty stdout from a successful hook as allow/continue.
}

export function denyPreToolUse(reason) {
  console.log(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: reason,
      },
    }),
  )
}
