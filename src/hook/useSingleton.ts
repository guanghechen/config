import React from 'react'

interface IDisposableSingleton {
  readonly name?: string
  dispose(): void
}

export const useSingleton = <T extends IDisposableSingleton>(fn: () => T): T | null => {
  const ref = React.useRef<T | null>(null)
  const [_, setTick] = React.useState<number>(0)

  const fnRef = React.useRef<() => T>(fn)
  fnRef.current = fn

  React.useEffect(() => {
    if (!ref.current) {
      ref.current = fnRef.current()

      const singleton: T = ref.current
      const name: string = singleton.name ?? singleton.constructor.name
      console.log(`[useSingleton] creating ${name}.`)
    }

    setTick(c => c + 1)

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
