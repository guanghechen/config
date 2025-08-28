import { chalk } from '@guanghechen/chalk/node'
import type { IReporter } from '@guanghechen/reporter'
import { Reporter, ReporterLevelEnum, resolveLevel } from '@guanghechen/reporter'
import type { IState } from '@guanghechen/viewmodel'
import { State } from '@guanghechen/viewmodel'
import type { FSWatcher } from 'chokidar'
import chokidar from 'chokidar'
import path from 'node:path'
import { normalizeFilepath, resolveRealFilepath } from './util/path'

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
  readonly files: {
    mds: string[] | null
  }
}

export type IWorkspaceMap = ReadonlyMap<string, IWorkspaceItem>

const YOZ_WORKSPACE_PREFIX = 'YOZ_WORKSPACE_'
const YOZ_WORKSPACE_ITEMS: IWorkspaceItem[] = Object.entries(process.env)
  .filter(([key, val]) => !!val && key.startsWith(YOZ_WORKSPACE_PREFIX))
  .map(([key, val]) => ({
    tag: key.slice(YOZ_WORKSPACE_PREFIX.length).toLowerCase(),
    path: resolveRealFilepath(val!),
    files: { mds: null },
  }))

class ServerViewModel {
  public readonly reporter: IReporter
  public readonly fileChanged$: IState<string | null>
  public readonly fileSwitch$: IState<string | null>
  public readonly fileSwitchArgForce$: IState<boolean>
  public readonly workspaceMap$: IState<IWorkspaceMap>
  protected readonly _watchingFilepaths: Set<string>
  protected _watcher: FSWatcher | null

  constructor() {
    const workspaceMap = new Map<string, IWorkspaceItem>()
    for (const item of YOZ_WORKSPACE_ITEMS) workspaceMap.set(item.tag, item)

    this.reporter = reporter
    this.fileChanged$ = new State<string | null>(null, { equals: () => false, delay: 20 })
    this.fileSwitch$ = new State<string | null>(null, { equals: () => false, delay: 20 })
    this.fileSwitchArgForce$ = new State<boolean>(false)
    this.workspaceMap$ = new State<IWorkspaceMap>(workspaceMap)
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

  public resolveFilepath = (workspace: string | null, relativePath: string): string => {
    const workspaceMap: IWorkspaceMap = this.workspaceMap$.getSnapshot()
    const item: IWorkspaceItem | undefined = workspaceMap.get(workspace?.toLowerCase() || '')
    const p = item ? path.join(item.path, relativePath) : relativePath
    return resolveRealFilepath(p)
  }

  public sharpFilepath = (filepath: string): { workspace: string | null; relativePath: string } => {
    const p: string = normalizeFilepath(filepath)
    const workspaceMap: IWorkspaceMap = this.workspaceMap$.getSnapshot()
    for (const item of workspaceMap.values()) {
      if (p.startsWith(item.path)) {
        return { workspace: item.tag, relativePath: p.slice(item.path.length) }
      }
    }
    return { workspace: null, relativePath: p }
  }
}

const state = new ServerViewModel()
export default state
