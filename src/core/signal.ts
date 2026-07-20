export interface IDisposable {
  dispose(): void
}

export type Event<T> = (listener: (value: T) => void) => IDisposable

export class Signal<T> implements IDisposable {
  private readonly listeners = new Set<(value: T) => void>()

  public readonly event: Event<T> = listener => {
    this.listeners.add(listener)
    return { dispose: () => this.listeners.delete(listener) }
  }

  public emit(value: T): void {
    for (const listener of [...this.listeners]) listener(value)
  }

  public dispose(): void {
    this.listeners.clear()
  }
}
