import { execFileSync } from "node:child_process"

// Codex starts hooks in a new session through the user's shell, so they have no
// controlling terminal and no /dev/tty, and its own tty is at most two parents up. Stop
// there: walking further would reach an outer session's terminal when this Codex is
// itself nested in a tool call.
export function terminalTty() {
  let pid = process.ppid
  for (let depth = 0; depth < 2 && pid > 1; depth++) {
    const [ppid, tty] = psRow(pid)
    if (tty && !/^\?+$/.test(tty)) return `/dev/${tty}`
    pid = Number(ppid)
  }
  return null
}

// timeout guards against the hook subprocess blocking forever on a stuck ps
function psRow(pid) {
  try {
    const out = execFileSync("ps", ["-o", "ppid=,tty=", "-p", String(pid)], {
      encoding: "utf-8",
      timeout: 1000,
    })
    return out.trim().split(/\s+/)
  } catch {
    return []
  }
}
