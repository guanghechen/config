import type { IWhiteboardFile, IWhiteboardFiles } from '../contracts'

export interface IResourceSnapshot {
  readonly data?: IWhiteboardFile
  readonly error?: string
}

export interface IMarkdownResources {
  get: (filepath: string) => IResourceSnapshot
  subscribe: (filepath: string, listener: () => void) => () => void
}

interface IResource {
  snapshot: IResourceSnapshot
  listeners: Set<() => void>
  controller?: AbortController
}

export class MarkdownResources implements IMarkdownResources {
  private files?: IWhiteboardFiles

  constructor(files?: IWhiteboardFiles) {
    this.files = files
  }

  private entries = new Map<string, IResource>()
  private queue = new Set<string>()
  private active = 0
  private timer?: ReturnType<typeof setInterval>
  private stopped = true

  private entry(filepath: string): IResource {
    let entry = this.entries.get(filepath)
    if (!entry) {
      entry = { snapshot: {}, listeners: new Set() }
      this.entries.set(filepath, entry)
    }
    return entry
  }
  public get = (filepath: string): IResourceSnapshot => this.entry(filepath).snapshot
  public subscribe = (filepath: string, listener: () => void): (() => void) => {
    const entry = this.entry(filepath)
    entry.listeners.add(listener)
    if ((!entry.controller || entry.controller.signal.aborted) && !this.queue.has(filepath))
      this.refresh(filepath)
    return () => {
      entry.listeners.delete(listener)
      if (!entry.listeners.size) {
        this.queue.delete(filepath)
        entry.controller?.abort()
      }
    }
  }
  public refresh = (filepath?: string): void => {
    if (filepath) {
      // Explicit file-change/save notifications supersede an in-flight response.
      this.entry(filepath).controller?.abort()
      this.queue.add(filepath)
    } else {
      for (const [key, entry] of this.entries) {
        if (entry.listeners.size && !entry.controller) this.queue.add(key)
      }
    }
    this.drain()
  }
  private async load(
    filepath: string,
    revision: string | undefined,
    signal: AbortSignal,
  ): Promise<IWhiteboardFile | null> {
    if (!this.files) throw new Error('File access is unavailable for this board')
    return this.files.load(filepath, revision, signal)
  }
  private drain(): void {
    if (this.stopped) return
    for (const filepath of this.queue) {
      if (this.active >= 4) break
      const entry = this.entry(filepath)
      if (entry.controller) continue
      this.queue.delete(filepath)
      this.active++
      const controller = new AbortController()
      entry.controller = controller
      void this.load(filepath, entry.snapshot.data?.revision, controller.signal)
        .then(data => {
          if (controller.signal.aborted) return
          if (data || entry.snapshot.error) {
            entry.snapshot = { data: data ?? entry.snapshot.data }
            for (const listener of entry.listeners) listener()
          }
        })
        .catch((error: unknown) => {
          if (controller.signal.aborted) return
          entry.snapshot = {
            ...entry.snapshot,
            error: error instanceof Error ? error.message : String(error),
          }
          for (const listener of entry.listeners) listener()
        })
        .finally(() => {
          if (entry.controller === controller) entry.controller = undefined
          this.active--
          this.drain()
        })
    }
  }
  public start = (): (() => void) => {
    this.stopped = false
    this.timer = setInterval(() => this.refresh(), 2500)
    const focus = (): void => this.refresh()
    const changed = (filepath: string): void => {
      for (const [key, entry] of this.entries) {
        if (
          entry.listeners.size &&
          (key === filepath || entry.snapshot.data?.filepath === filepath)
        )
          this.refresh(key)
      }
    }
    window.addEventListener('focus', focus)
    let unsubscribe: (() => void) | undefined
    try {
      unsubscribe = this.files?.subscribe?.(changed)
    } catch {
      // File notifications are optional; polling and focus refresh remain available.
    }
    this.refresh()
    return () => {
      this.stopped = true
      clearInterval(this.timer)
      window.removeEventListener('focus', focus)
      unsubscribe?.()
      for (const entry of this.entries.values()) entry.controller?.abort()
      this.queue.clear()
    }
  }
}
