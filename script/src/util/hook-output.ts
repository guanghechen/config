export type IPermissionDecision = "allow" | "deny" | "ask"

export function outputHook(
  eventName: string,
  decision: IPermissionDecision,
  reason?: string,
): void {
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
