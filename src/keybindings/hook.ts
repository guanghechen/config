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
