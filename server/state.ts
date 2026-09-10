import type { IReporter } from '@guanghechen/reporter'
import { Reporter, resolveLogLevel } from '@guanghechen/reporter'
import type { IState } from '@guanghechen/viewmodel'
import { State } from '@guanghechen/viewmodel'
import type { FSWatcher } from 'chokidar'
import chokidar from 'chokidar'
import path from 'node:path'
import { ROOT_DIR } from '../env'
import { configureRoots } from './util/file-access'

const reporter = new Reporter({
  prefix: 'guanghechen',
  level: resolveLogLevel(process.env.LOG_LEVEL || 'info') ?? 'info',
  flight: {
    color: true,
    date: true,
  },
})

const roots = configureRoots(process.env, path.resolve(ROOT_DIR, 'demo'))

class ServerViewModel {
  public readonly authLogout$ = new State<string | null>(null, { equals: () => false })
  public readonly reporter: IReporter
  public readonly fileChanged$: IState<string | null>
  public readonly fileSwitch$: IState<string | null>
  public readonly fileSwitchArgForce$: IState<boolean>
  public readonly access = roots.access
  public readonly defaultWorkspaceRoots = roots.defaultWorkspaceRoots
  public readonly legacyWorkspaces = roots.legacyWorkspaces
  protected readonly _watchingFilepaths: Set<string>
  protected _watcher: FSWatcher | null

  constructor() {
    this.reporter = reporter
    this.fileChanged$ = new State<string | null>(null, { equals: () => false, delay: 20 })
    this.fileSwitch$ = new State<string | null>(null, { equals: () => false, delay: 20 })
    this.fileSwitchArgForce$ = new State<boolean>(false)
    this._watchingFilepaths = new Set<string>()
    this._watcher = null
  }

  public watch = (...filepaths: string[]): void => {
    const { fileChanged$, _watchingFilepaths } = this
    const fps: string[] = filepaths
      .map(p => this.access.resolve(p, 'file'))
      .filter(p => !this._watchingFilepaths.has(p))
    if (fps.length <= 0) return

    for (const fp of fps) {
      reporter.debug(`  watching: ${fp}.`)
      _watchingFilepaths.add(fp)
    }

    if (this._watcher) {
      this._watcher.add(fps)
    } else {
      const watcher = chokidar.watch(fps, {
        persistent: true,
        ignoreInitial: true,
      })
      this._watcher = watcher

      watcher.on('change', filepath => {
        try {
          fileChanged$.next(this.access.resolve(filepath, 'file'))
        } catch {
          // A deleted or replaced watched path must not publish an unauthorized file.
          this._watcher?.unwatch(filepath)
          _watchingFilepaths.delete(filepath)
        }
      })
    }
  }
}

const state = new ServerViewModel()
export default state
