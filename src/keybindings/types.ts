export type Platform = 'osx' | 'win' | 'nix' | 'all'

export interface IKeyBinding {
  key: string
  ctrlKey?: boolean
  altKey?: boolean
  shiftKey?: boolean
  metaKey?: boolean
  callback: (event: KeyboardEvent) => void
  priority?: number
  platform?: Platform
}

export interface IKeyBindingManager {
  register: (binding: IKeyBinding) => void
  unregister: (binding: IKeyBinding) => void
  handleKeyDown: (event: KeyboardEvent) => void
  destroy: () => void
}
