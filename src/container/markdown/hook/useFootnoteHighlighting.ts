import React from 'react'

export const useFootnoteHighlighting = (
  targetRef: React.RefObject<HTMLElement | null>,
  targetId: string,
): boolean => {
  const [highlighting, setHighlighting] = React.useState<boolean>(false)

  React.useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | null = null

    const onHashChange = (): void => {
      const hash = window.location.hash

      if (hash === '#' + targetId) {
        setHighlighting(true)
        timer = setTimeout(() => {
          timer = null
          setHighlighting(false)
        }, 3000)

        targetRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' })
      }
    }

    onHashChange()

    window.addEventListener('hashchange', onHashChange)
    return () => {
      if (timer !== null) clearTimeout(timer)
      window.removeEventListener('hashchange', onHashChange)
    }
  }, [targetRef, targetId])

  return highlighting
}
