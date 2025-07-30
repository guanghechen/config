import type { IKeyBinding, IKeyBindingManager, Platform } from './types'

function getCurrentPlatform(): Platform {
  const userAgent = navigator.userAgent
  if (userAgent.includes('Mac')) return 'osx'
  if (userAgent.includes('Win')) return 'win'
  return 'nix'
}

export class KeyBindingManagerImpl implements IKeyBindingManager {
  private bindings: IKeyBinding[] = []
  private isListening = false
  private currentPlatform: Platform

  constructor() {
    this.handleKeyDown = this.handleKeyDown.bind(this)
    this.currentPlatform = getCurrentPlatform()
  }

  public register(binding: IKeyBinding): void {
    // Only register bindings that match current platform or are universal
    if (
      binding.platform &&
      binding.platform !== 'all' &&
      binding.platform !== this.currentPlatform
    ) {
      return
    }

    this.bindings.push(binding)
    this.bindings.sort((a, b) => (b.priority || 0) - (a.priority || 0))

    if (!this.isListening) {
      document.addEventListener('keydown', this.handleKeyDown, true)
      this.isListening = true
    }
  }

  public unregister(binding: IKeyBinding): void {
    const index = this.bindings.indexOf(binding)
    if (index >= 0) {
      this.bindings.splice(index, 1)
    }

    if (this.bindings.length === 0 && this.isListening) {
      document.removeEventListener('keydown', this.handleKeyDown, true)
      this.isListening = false
    }
  }

  public handleKeyDown(event: KeyboardEvent): void {
    for (const binding of this.bindings) {
      if (this.matchesBinding(event, binding)) {
        binding.callback(event)
        return
      }
    }
  }

  public destroy(): void {
    if (this.isListening) {
      document.removeEventListener('keydown', this.handleKeyDown, true)
      this.isListening = false
    }
    this.bindings = []
  }

  private matchesBinding(event: KeyboardEvent, binding: IKeyBinding): boolean {
    return (
      event.key === binding.key &&
      !!event.ctrlKey === !!binding.ctrlKey &&
      !!event.altKey === !!binding.altKey &&
      !!event.shiftKey === !!binding.shiftKey &&
      !!event.metaKey === !!binding.metaKey
    )
  }
}

let globalKeyBindingManager: IKeyBindingManager | null = null

export function getKeyBindingManager(): IKeyBindingManager {
  if (!globalKeyBindingManager) {
    globalKeyBindingManager = new KeyBindingManagerImpl()
  }
  return globalKeyBindingManager
}
