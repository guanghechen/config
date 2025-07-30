export interface IKeyBinding {
  key: string
  ctrlKey?: boolean
  altKey?: boolean
  shiftKey?: boolean
  metaKey?: boolean
  callback: (event: KeyboardEvent) => void
  priority?: number
}

export interface IKeyBindingManager {
  register: (binding: IKeyBinding) => void
  unregister: (binding: IKeyBinding) => void
  handleKeyDown: (event: KeyboardEvent) => void
  destroy: () => void
}
