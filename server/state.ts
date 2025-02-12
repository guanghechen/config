import { chalk } from '@guanghechen/chalk/node'
import type { IReporter } from '@guanghechen/reporter'
import { Reporter, ReporterLevelEnum, resolveLevel } from '@guanghechen/reporter'
import type { IState } from '@guanghechen/viewmodel'
import { State } from '@guanghechen/viewmodel'
import type { FSWatcher } from 'chokidar'
import chokidar from 'chokidar'
import path from 'node:path'

const reporter = new Reporter(chalk, {
  baseName: 'guanghechen',
  level: resolveLevel(process.env.LOG_LEVEL || ReporterLevelEnum.INFO) || ReporterLevelEnum.INFO,
  flights: {
    colorful: true,
    date: true,
    title: false,
  },
})

class ServerViewModel {
  public readonly fileChanged$: IState<string | null>
  public readonly fileSwitch$: IState<string | null>
  public readonly reporter: IReporter
  protected readonly _watchingFilepaths: Set<string>
  protected _watcher: FSWatcher | null

  constructor() {
    this.fileChanged$ = new State<string | null>(null, { equals: () => false, delay: 20 })
    this.fileSwitch$ = new State<string | null>(null, { equals: () => false, delay: 20 })
    this.reporter = reporter
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
      reporter.verbose('--> watching {}.', fp)
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
