import { useEventCallback } from '@guanghechen/react-hooks'
import React from 'react'

export const useScrollToTop = (
  container: HTMLDivElement | null,
): { visible: boolean; scrollToTop: () => void } => {
  const [visible, setVisible] = React.useState(false)

  const scrollToTop = useEventCallback((): void => {
    if (container) {
      container.scrollTo({ top: 0, behavior: 'smooth' })
    }
  })

  React.useEffect(() => {
    if (!container) return

    const onScroll = (): void => {
      if (container.scrollTop > 100) setVisible(true)
      else setVisible(false)
    }

    onScroll()
    container.addEventListener('scroll', onScroll)
    return () => container.removeEventListener('scroll', onScroll)
  }, [container])

  return { visible, scrollToTop }
}
