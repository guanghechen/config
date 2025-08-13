import React from 'react'

interface IDisposableSingleton {
  readonly name?: string
  dispose(): void
}

export const useSingleton = <T extends IDisposableSingleton>(fn: () => T): T => {
  const ref = React.useRef<T | null>(null)
  if (!ref.current) {
    ref.current = fn()

    const singleton: T = ref.current
    const name: string = singleton.name ?? singleton.constructor.name
    console.log(`[useSingleton] creating ${name}.`)
  }

  React.useEffect(() => {
    return () => {
      const singleton: T | null = ref.current
      if (!singleton) return

      const name: string = singleton.name ?? singleton.constructor.name
      console.log(`[useSingleton] disposing ${name}.`)

      ref.current = null
      singleton.dispose()
    }
  }, [])

  return ref.current
}
