import { spawn } from 'node:child_process'
import { IS_WIN } from '#env'

/** @import { Reporter } from '#stl/reporter' */

/**
 * @typedef {Object} IExecParams
 * @property {Reporter} reporter
 * @property {string} cmd
 * @property {string[]} [args]
 * @property {string} [cwd]
 * @property {Record<string, string>} [env]
 * @property {number} [timeout]
 * @property {boolean} [silent]
 */

/**
 * @typedef {Object} IExecResult
 * @property {string} stdout
 * @property {string} stderr
 * @property {number} code
 */

/**
 * Execute a command and return the result.
 *
 * @param {IExecParams} params
 * @return {Promise<IExecResult>}
 */
export async function exec(params) {
  const { reporter, cmd, args = [], cwd, env, timeout, silent = false } = params

  return new Promise((resolve, reject) => {
    let stdout = ''
    let stderr = ''
    let terminated = false
    /** @type {ReturnType<typeof setTimeout> | undefined} */
    let timer

    /**
     * @param {number} code
     */
    const onExit = code => {
      if (terminated) return
      terminated = true
      if (timer) clearTimeout(timer)

      const result = { stdout: stdout.trimEnd(), stderr: stderr.trimEnd(), code }
      if (code === 0) {
        resolve(result)
      } else {
        if (!silent) {
          reporter.error('Command failed.', {
            cmd,
            args,
            code,
            stderr: result.stderr || result.stdout,
          })
        }
        const error = new Error(`Command failed with code ${code}: ${cmd}`)
        Object.assign(error, result)
        reject(error)
      }
    }

    /** @param {Error} error */
    const onError = error => {
      if (terminated) return
      terminated = true
      if (timer) clearTimeout(timer)

      if (!silent) {
        reporter.error('Command error.', { cmd, args, error })
      }
      reject(error)
    }

    try {
      const child = spawn(cmd, args, {
        cwd: cwd ?? process.cwd(),
        env: env ? { ...process.env, ...env } : process.env,
        stdio: ['ignore', 'pipe', 'pipe'],
      })

      child.stdout?.on('data', (/** @type {Buffer} */ data) => {
        stdout += data.toString('utf8')
      })
      child.stderr?.on('data', (/** @type {Buffer} */ data) => {
        stderr += data.toString('utf8')
      })
      child.on('error', onError)
      child.on('close', code => onExit(code ?? 1))

      if (timeout && timeout > 0) {
        timer = setTimeout(() => {
          if (!terminated) {
            child.kill('SIGTERM')
            onError(new Error(`Command timed out after ${timeout}ms: ${cmd}`))
          }
        }, timeout)
      }
    } catch (error) {
      onError(/** @type {Error} */ (error))
    }
  })
}

/**
 * Check if a command exists in PATH.
 *
 * @param {Reporter} reporter
 * @param {string} cmd
 * @return {Promise<boolean>}
 */
export async function command_exists(reporter, cmd) {
  try {
    const result = await exec({
      reporter,
      cmd: IS_WIN ? 'where.exe' : 'which',
      args: [cmd],
      silent: true,
    })
    return !!result.stdout
  } catch {
    return false
  }
}
