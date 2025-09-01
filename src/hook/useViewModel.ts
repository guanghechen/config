import type { IViewModel } from '@guanghechen/viewmodel'
import React from 'react'

type V = IViewModel & { name?: string | null }
type F<T extends V> = () => T | Promise<T>

export const useViewModel = <T extends V>(fn: F<T>): T | null => {
  const ref = React.useRef<T | null>(null)
  const [_, setTick] = React.useState<number>(0)

  const fnRef = React.useRef<F<T>>(fn)
  fnRef.current = fn

  React.useEffect(() => {
    let cancelled: boolean = false
    if (!ref.current) {
      const promise: Promise<T> = Promise.resolve(fnRef.current())
      void promise
        .then((viewmodel: T): void => {
          ref.current = viewmodel
          const name: string = viewmodel.name || viewmodel.constructor.name
          console.log(`[useViewModel] creating ${name}.`)

          if (!cancelled) {
            setTick(c => c + 1)
          }
        })
        .catch(error => {
          ref.current = null
          console.log('[useViewModel] failed. error:', error)

          if (!cancelled) {
            setTick(c => c + 1)
          }
        })
    }

    return () => {
      cancelled = true
      const viewmodel: T | null = ref.current
      if (!viewmodel) return

      const name: string = viewmodel.name || viewmodel.constructor.name
      console.log(`[useViewModel] disposing ${name}.`)

      ref.current = null
      viewmodel.dispose()
    }
  }, [])

  return ref.current
}
