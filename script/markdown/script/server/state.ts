import type { IState } from '@guanghechen/viewmodel'
import { State } from '@guanghechen/viewmodel'
import type { FSWatcher } from 'chokidar'
import chokidar from 'chokidar'
import path from 'node:path'

class ServerViewModel {
  public readonly newChangedFilepath$: IState<string | null>
  protected readonly _watchingFilepaths: Set<string>
  protected _watcher: FSWatcher | null

  constructor() {
    this.newChangedFilepath$ = new State<string | null>(null, { equals: () => false })
    this._watchingFilepaths = new Set<string>()
    this._watcher = null
  }

  public watch = (...filepaths: string[]): void => {
    const { newChangedFilepath$, _watchingFilepaths } = this
    const fps: string[] = filepaths
      .map(p => path.normalize(p))
      .filter(p => !this._watchingFilepaths.has(p))
    if (fps.length <= 0) return

    for (const fp of fps) {
      console.log('--> wathcing', fp)
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
        console.log('--> file changed', filepath)
        newChangedFilepath$.next(filepath)
      })
    }
  }
}

const state = new ServerViewModel()
export default state
