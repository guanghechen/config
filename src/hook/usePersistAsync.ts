import { useEventCallback } from '@guanghechen/react-hooks'
import type { IState } from '@guanghechen/react-viewmodel'
import { Computed } from '@guanghechen/react-viewmodel'
import throttle from 'lodash.throttle'
import React from 'react'
import { universalStorage } from '@/util/storage'

interface IViewModel {
  dump(): any
  disposed?: boolean
}

interface IUsePersistAsyncOptions {
  readonly throttleMs?: number
}

const DEFAULT_OPTIONS: Required<IUsePersistAsyncOptions> = {
  throttleMs: 2000,
}

export const usePersistAsync = <T extends IViewModel>(
  viewmodel: T,
  storageKey: string,
  observables: Array<IState<any>>,
  options: IUsePersistAsyncOptions = {},
): void => {
  const { throttleMs } = { ...DEFAULT_OPTIONS, ...options, }
  const isMountedRef = React.useRef<boolean>(true)

  const persist = useEventCallback(async () => {
    if (viewmodel.disposed || !isMountedRef.current) return

    try {
      const data = viewmodel.dump()
      await universalStorage.setContext(storageKey, data)
    } catch (error) {
      console.warn(`Failed to persist data for key "${storageKey}":`, error)
    }
  })
  const throttledPersist = React.useMemo(
    () => throttle(persist, throttleMs, { leading: true }),
    [persist, throttleMs],
  )

  React.useEffect(() => {
    isMountedRef.current = true
    const computed = Computed.fromObservables(observables, throttledPersist)
    return () => {
      computed.dispose()
      throttledPersist.cancel()
      void persist()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, observables)
}
