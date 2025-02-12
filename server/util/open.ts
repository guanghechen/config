// See https://github.com/vitejs/vite/blob/b44e3d43db65babe1c32e143964add02e080dc15/packages/vite/src/node/server/openBrowser.ts#L1

/* eslint-disable no-param-reassign */
import spawn from 'cross-spawn'
import type { ExecOptions } from 'node:child_process'
import { exec } from 'node:child_process'
import path from 'node:path'
import open from 'open'
import type { Options as IOpenOptions } from 'open'
import { ROOT_DIR } from '../../env'
import state from '../state'

const VITE_PACKAGE_DIR = path.resolve(ROOT_DIR, 'node_modules', 'vite')

const supportedChromiumBrowsers = [
  'Google Chrome Canary',
  'Google Chrome Dev',
  'Google Chrome Beta',
  'Google Chrome',
  'Microsoft Edge',
  'Brave Browser',
  'Vivaldi',
  'Chromium',
]

/**
 * Reads the BROWSER environment variable and decides what to do with it.
 */
export async function openBrowser(url: string, opt: string | true): Promise<void> {
  // The browser executable to open.
  // See https://github.com/sindresorhus/open#app for documentation.
  const browser = typeof opt === 'string' ? opt : process.env.BROWSER || ''
  if (browser.toLowerCase().endsWith('.js')) {
    await executeNodeScript(url, browser)
  } else if (browser.toLowerCase() !== 'none') {
    const browserArgs = process.env.BROWSER_ARGS ? process.env.BROWSER_ARGS.split(' ') : []
    await startBrowserProcess(url, browser, browserArgs)
  }
}

function executeNodeScript(url: string, scriptPath: string): Promise<boolean> {
  const extraArgs = process.argv.slice(2)
  const child = spawn(process.execPath, [scriptPath, ...extraArgs, url], {
    stdio: 'inherit',
  })
  return new Promise<boolean>(resolve => {
    child.on('close', code => {
      if (code !== 0) {
        state.reporter.error(
          `\nThe script specified as BROWSER environment variable failed.\n\n ${scriptPath} exited with code ${code}.`,
        )
        resolve(false)
        return
      }
      resolve(true)
    })
  })
}

async function startBrowserProcess(
  url: string,
  browser?: string,
  browserArgs?: string[],
): Promise<boolean> {
  // If we're on OS X, the user hasn't specifically
  // requested a different browser, we can try opening
  // a Chromium browser with AppleScript. This lets us reuse an
  // existing tab when possible instead of creating a new one.
  const preferredOSXBrowser = browser === 'google chrome' ? 'Google Chrome' : browser
  const shouldTryOpenChromeWithAppleScript =
    process.platform === 'darwin' &&
    (!preferredOSXBrowser || supportedChromiumBrowsers.includes(preferredOSXBrowser))

  if (shouldTryOpenChromeWithAppleScript) {
    try {
      const ps = await execAsync('ps cax')
      const openedBrowser =
        preferredOSXBrowser && ps.includes(preferredOSXBrowser)
          ? preferredOSXBrowser
          : supportedChromiumBrowsers.find(b => ps.includes(b))
      if (openedBrowser) {
        // Try our best to reuse existing tab with AppleScript
        await execAsync(`osascript openChrome.applescript "${url}" "${openedBrowser}"`, {
          cwd: path.join(VITE_PACKAGE_DIR, 'bin'),
        })
        return true
      }
    } catch {
      // Ignore errors
    }
  }

  // Another special case: on OS X, check if BROWSER has been set to "open".
  // In this case, instead of passing the string `open` to `open` function (which won't work),
  // just ignore it (thus ensuring the intended behavior, i.e. opening the system browser):
  // https://github.com/facebook/create-react-app/pull/1690#issuecomment-283518768
  if (process.platform === 'darwin' && browser === 'open') {
    browser = undefined
  }

  // Fallback to open
  // (It will always open new tab)
  try {
    const options: IOpenOptions = browser ? { app: { name: browser, arguments: browserArgs } } : {}

    new Promise((_, reject) => {
      open(url, options)
        .then(subprocess => {
          subprocess.on('error', reject)
        })
        .catch(reject)
    }).catch(err => {
      state.reporter.error(err.stack || err.message)
    })

    return true
  } catch {
    return false
  }
}

function execAsync(command: string, options?: ExecOptions): Promise<string> {
  return new Promise((resolve, reject) => {
    exec(command, options, (error, stdout) => {
      if (error) {
        reject(error)
      } else {
        resolve(stdout.toString())
      }
    })
  })
}
