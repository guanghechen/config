#!/usr/bin/env node

import { readFileSync, writeFileSync } from "node:fs"
import { execFileSync } from "node:child_process"

const BODY_MAX = 200

main()

function main() {
  const input = readInput()
  const event = input.hook_event_name || "Claude Code"
  const message =
    input.message ||
    input.last_assistant_message ||
    (event === "Stop" ? "任务执行完毕" : "有新通知")

  notify(truncate(sanitize(`Claude Code: ${message}`)))
}

function readInput() {
  try {
    return JSON.parse(readFileSync(0, "utf-8"))
  } catch {
    return {}
  }
}

// 两条互补信号：
//  1) BEL → 自己 pane 的 pty，设所在 session 的 window bell flag（切回该 session 可见）；
//  2) OSC 9 → 所有 attached client 的 tty，直达外层终端弹桌面通知。直写 client tty 不经
//     pane→tmux 转发，故无需 passthrough，也不受 Claude 所在 pane/session 可见性影响。
function notify(body) {
  const bel = "\x07"

  const paneTty = tmuxPaneTty()
  if (paneTty) {
    try {
      writeFileSync(paneTty, bel)
    } catch {}
  }

  const clientTtys = tmuxClientTtys()
  if (clientTtys.length > 0) {
    let delivered = false
    for (const tty of clientTtys) {
      try {
        writeFileSync(tty, osc9(body))
        delivered = true
      } catch {}
    }
    if (delivered) return
  }

  // 兜底：非 tmux 或无 attached client → 控制终端
  try {
    writeFileSync("/dev/tty", bel + osc9(body))
  } catch {
    process.stderr.write(bel)
  }
}

function tmuxPaneTty() {
  const pane = process.env.TMUX_PANE
  if (!pane || !process.env.TMUX) return null

  // hook 子进程的 /dev/tty 未必是该 pane 的 pty，故经 pane id 显式定位
  try {
    return execFileSync("tmux", ["display", "-p", "-t", pane, "#{pane_tty}"], {
      encoding: "utf-8",
    }).trim()
  } catch {
    return null
  }
}

// 枚举该 tmux server 上所有 attached client 的 tty。无论 Claude 在哪个 session、
// 用户 switch-client 到哪，client tty 始终指向用户当前的外层终端。
function tmuxClientTtys() {
  if (!process.env.TMUX) return []

  try {
    return execFileSync("tmux", ["list-clients", "-F", "#{client_tty}"], {
      encoding: "utf-8",
    })
      .split("\n")
      .map((s) => s.trim())
      .filter(Boolean)
  } catch {
    return []
  }
}

function osc9(text) {
  return `\x1b]9;${text}\x07`
}

function truncate(text) {
  return text.length > BODY_MAX ? `${text.slice(0, BODY_MAX - 3)}...` : text
}

function sanitize(text) {
  return String(text)
    .replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
}
