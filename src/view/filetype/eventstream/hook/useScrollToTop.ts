import { useEventCallback } from '@guanghechen/react-hooks'
import React from 'react'

interface IResult {
  readonly visible: boolean
  readonly scrollToTop: () => void
}

export const useScrollToTop = (container: HTMLElement | null): IResult => {
  const [visible, setVisible] = React.useState(false)

  const scrollToTop = useEventCallback((): void => {
    if (container) container.scrollTo({ top: 0, behavior: 'smooth' })
  })

  React.useEffect(() => {
    if (!container) return

    const onScroll = (): void => {
      setVisible(container.scrollTop > 100)
    }

    onScroll()
    container.addEventListener('scroll', onScroll)
    return () => container.removeEventListener('scroll', onScroll)
  }, [container])

  return { visible, scrollToTop }
}
