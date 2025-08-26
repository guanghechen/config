import { useEventCallback } from '@guanghechen/react-hooks'
import type { IState } from '@guanghechen/react-viewmodel'
import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'

interface IViewModel {
  dump(): any
  disposed?: boolean
}

interface IUsePersistOptions {
  readonly debounceMs?: number
  readonly enableUnmountPersist?: boolean
  readonly enableBeforeUnloadPersist?: boolean
}

const DEFAULT_OPTIONS: Required<IUsePersistOptions> = {
  debounceMs: 3000,
  enableUnmountPersist: true,
  enableBeforeUnloadPersist: true,
}

export const usePersist = <T extends IViewModel>(
  viewmodel: T,
  storageKey: string,
  observables: Array<IState<any>>,
  options: IUsePersistOptions = {},
): void => {
  const { debounceMs, enableUnmountPersist, enableBeforeUnloadPersist } = {
    ...DEFAULT_OPTIONS,
    ...options,
  }
  const debounceTimeoutRef = React.useRef<NodeJS.Timeout | null>(null)

  const persist = React.useCallback(() => {
    if (viewmodel.disposed) return

    debounceTimeoutRef.current = null
    try {
      const data = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    } catch (error) {
      console.warn(`Failed to persist data for key "${storageKey}":`, error)
    }
  }, [viewmodel, storageKey])

  const debouncedPersist = useEventCallback(() => {
    if (debounceTimeoutRef.current) clearTimeout(debounceTimeoutRef.current)
    debounceTimeoutRef.current = setTimeout(persist, debounceMs)
  })

  React.useEffect(() => {
    const computed = Computed.fromObservables(observables, debouncedPersist)
    return () => {
      computed.dispose()
      if (debounceTimeoutRef.current) {
        clearTimeout(debounceTimeoutRef.current)
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, observables)

  React.useEffect(() => {
    if (!enableBeforeUnloadPersist) return

    const onBeforeUnload = (): void => {
      if (debounceTimeoutRef.current) clearTimeout(debounceTimeoutRef.current)
      persist()
    }

    window.addEventListener('beforeunload', onBeforeUnload)
    return () => {
      window.removeEventListener('beforeunload', onBeforeUnload)
    }
  }, [persist, enableBeforeUnloadPersist])

  React.useEffect(() => {
    if (!enableUnmountPersist) return

    return () => {
      if (debounceTimeoutRef.current) clearTimeout(debounceTimeoutRef.current)
      persist()
    }
  }, [persist, enableUnmountPersist])
}
