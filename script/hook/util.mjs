export function outputHook(eventName, decision, reason) {
  console.log(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: eventName,
        permissionDecision: decision,
        ...(reason && { permissionDecisionReason: reason }),
      },
    }),
  )
}
