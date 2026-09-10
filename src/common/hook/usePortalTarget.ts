import React from 'react'

export function usePortalTarget(selector: string): Element | null {
  const [target, setTarget] = React.useState<Element | null>(null)
  React.useEffect(() => {
    setTarget(document.querySelector(selector))
  }, [selector])
  return target
}
