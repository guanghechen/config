import { chalk } from '@guanghechen/chalk/node'
import type { IReporter } from '@guanghechen/reporter'
import { Reporter, ReporterLevelEnum, resolveLevel } from '@guanghechen/reporter'
import type { IState } from '@guanghechen/viewmodel'
import { State } from '@guanghechen/viewmodel'
import type { FSWatcher } from 'chokidar'
import chokidar from 'chokidar'
import path from 'node:path'
import { resolveRealFilepath } from './util/path'

const reporter = new Reporter(chalk, {
  baseName: 'guanghechen',
  level: resolveLevel(process.env.LOG_LEVEL || ReporterLevelEnum.INFO) || ReporterLevelEnum.INFO,
  flights: {
    colorful: true,
    date: true,
    title: false,
  },
})

export interface IWorkspaceItem {
  readonly tag: string
  readonly path: string
}

export type IWorkspaceMap = Record<string, IWorkspaceItem>

const YOZORA_WORKSPACE_PREFIX = 'YOZORA_WORKSPACE_'
const YOZORA_WORKSPACE_ENVS: IWorkspaceItem[] = Object.entries(process.env)
  .filter(([key, val]) => !!val && key.startsWith(YOZORA_WORKSPACE_PREFIX))
  .map(([key, val]) => ({
    tag: key.slice(YOZORA_WORKSPACE_PREFIX.length).toLowerCase(),
    path: resolveRealFilepath(val!),
  }))

class ServerViewModel {
  public readonly reporter: IReporter
  public readonly fileChanged$: IState<string | null>
  public readonly fileSwitch$: IState<string | null>
  public readonly fileSwitchArgForce$: IState<boolean>
  public readonly workspaces$: IState<IWorkspaceMap>
  protected readonly _watchingFilepaths: Set<string>
  protected _watcher: FSWatcher | null

  constructor() {
    this.fileChanged$ = new State<string | null>(null, { equals: () => false, delay: 20 })
    this.fileSwitch$ = new State<string | null>(null, { equals: () => false, delay: 20 })
    this.fileSwitchArgForce$ = new State<boolean>(false)
    this.reporter = reporter
    this.workspaces$ = new State<IWorkspaceMap>(
      Object.fromEntries(YOZORA_WORKSPACE_ENVS.map(item => [item.tag, item])),
    )
    this._watchingFilepaths = new Set<string>()
    this._watcher = null
  }

  public watch = (...filepaths: string[]): void => {
    const { fileChanged$, _watchingFilepaths } = this
    const fps: string[] = filepaths
      .map(p => path.normalize(p))
      .filter(p => !this._watchingFilepaths.has(p))
    if (fps.length <= 0) return

    for (const fp of fps) {
      reporter.verbose('  watching: {}.', fp)
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
        reporter.debug('--> file changed {}.', filepath)
        fileChanged$.next(filepath)
      })
    }
  }
}

const state = new ServerViewModel()
export default state
