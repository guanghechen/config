// Locates and runs the developer tools that repository checks use.
import { spawnSync } from "node:child_process"
import { join } from "node:path"

/** Runs `command` and returns its result; throws with stderr when it fails or exits outside `statuses`. */
export function run(command, args, { statuses = [0], ...options } = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", ...options })
  if (result.error) throw new Error(`${command}: ${result.error.message}`)
  if (!statuses.includes(result.status)) {
    const detail = result.stderr?.trim() || `status ${result.status ?? result.signal}`
    throw new Error(`${command} ${args.join(" ")}: ${detail}`)
  }
  return result
}

/** Version, $VIMRUNTIME and data directory of the `nvim` on PATH, read without user configuration. */
export function resolveNeovim() {
  const lua =
    "io.stdout:write(vim.json.encode({ version = tostring(vim.version()), " +
    'runtime = vim.env.VIMRUNTIME, data = vim.fn.stdpath("data") }))'
  return JSON.parse(run("nvim", ["--clean", "--headless", "-c", `lua ${lua}`, "-c", "qa!"]).stdout)
}

/** Path of an executable that Mason installed under the Neovim data directory. */
export function masonBin(neovim, name) {
  return join(neovim.data, "mason", "bin", name)
}
