import React from 'react'

export const useScrollToTop = (
  container: HTMLElement | null,
): { visible: boolean; scrollToTop: () => void } => {
  const [visible, setVisible] = React.useState(false)

  React.useEffect(() => {
    if (!container) return

    const handleScroll = (): void => {
      setVisible(container.scrollTop > 300)
    }

    container.addEventListener('scroll', handleScroll)
    return () => container.removeEventListener('scroll', handleScroll)
  }, [container])

  const scrollToTop = React.useCallback(() => {
    if (container) {
      container.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }, [container])

  return { visible, scrollToTop }
}
