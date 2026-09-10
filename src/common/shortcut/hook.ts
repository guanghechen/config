import React from 'react'
import { getKeyBindingManager } from './manager'
import type { IKeyBinding } from './types'

export function useKeyBinding(binding: IKeyBinding): void {
  React.useEffect(() => {
    const manager = getKeyBindingManager()
    manager.register(binding)

    return () => {
      manager.unregister(binding)
    }
  }, [binding])
}

export function useKeyBindings(bindings: IKeyBinding[]): void {
  React.useEffect(() => {
    const manager = getKeyBindingManager()

    for (const binding of bindings) {
      manager.register(binding)
    }

    return () => {
      for (const binding of bindings) {
        manager.unregister(binding)
      }
    }
  }, [bindings])
}
