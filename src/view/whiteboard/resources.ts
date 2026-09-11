import type { IReferencedText } from '@/shared/api/whiteboard'
import { loadReferencedText } from '@/shared/api/whiteboard'

export interface IResourceSnapshot {
  readonly data?: IReferencedText
  readonly error?: string
}

interface IResource {
  snapshot: IResourceSnapshot
  listeners: Set<() => void>
  controller?: AbortController
}

export class MarkdownResources {
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
    if (!entry.controller && !this.queue.has(filepath)) this.refresh(filepath)
    return () => {
      entry.listeners.delete(listener)
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
      void loadReferencedText(filepath, entry.snapshot.data?.revision, controller.signal)
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
    const changed = ({ filepath }: { filepath: string }): void => {
      for (const [key, entry] of this.entries) {
        if (
          entry.listeners.size &&
          (key === filepath || entry.snapshot.data?.filepath === filepath)
        )
          this.refresh(key)
      }
    }
    window.addEventListener('focus', focus)
    import.meta.hot?.on('guanghechen/file-changed', changed)
    this.refresh()
    return () => {
      this.stopped = true
      clearInterval(this.timer)
      window.removeEventListener('focus', focus)
      import.meta.hot?.off('guanghechen/file-changed', changed)
      for (const entry of this.entries.values()) entry.controller?.abort()
      this.queue.clear()
    }
  }
}
