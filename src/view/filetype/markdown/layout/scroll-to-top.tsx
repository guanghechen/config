import React from 'react'

export const ScrollToTop: React.FC = () => {
  const handleClick = React.useCallback((event: React.MouseEvent<HTMLButtonElement>): void => {
    const card = event.currentTarget.closest<HTMLElement>('.vlm-p-content')
    if (!card) return

    const behavior: ScrollBehavior = window.matchMedia('(prefers-reduced-motion: reduce)').matches
      ? 'auto'
      : 'smooth'
    const overflowY = window.getComputedStyle(card).overflowY
    if (overflowY === 'auto' || overflowY === 'scroll') {
      card.scrollTo({ top: 0, behavior })
      return
    }

    const root = card.closest<HTMLElement>('.vl-root')
    const topbar = root?.querySelector<HTMLElement>('.vl-topbar')
    const top = window.scrollY + card.getBoundingClientRect().top - (topbar?.offsetHeight ?? 0)
    window.scrollTo({ top: Math.max(0, top), behavior })
  }, [])

  return (
    <button
      type="button"
      title="Scroll to top"
      aria-label="Scroll to top"
      onClick={handleClick}
      className="pointer-events-auto flex h-8 w-8 items-center justify-center rounded-full border border-gray-200 bg-white/85 text-gray-500 shadow-md backdrop-blur-sm transition-colors hover:bg-gray-100 hover:text-gray-900 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500 dark:border-gray-600 dark:bg-gray-800/85 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white"
    >
      <svg
        aria-hidden="true"
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="m6 10 6-6 6 6" />
        <path d="M12 4v16" />
      </svg>
    </button>
  )
}

ScrollToTop.displayName = 'MarkdownViewScrollToTop'
