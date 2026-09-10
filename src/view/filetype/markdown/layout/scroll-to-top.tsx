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
      className="pointer-events-auto flex h-8 w-8 items-center justify-center rounded-full border border-[var(--vscode-border)] bg-[var(--vscode-surface-background)] text-[var(--vscode-muted-foreground)] shadow-md backdrop-blur-sm transition-colors hover:bg-[var(--vscode-list-hover-background)] hover:text-[var(--vscode-foreground)] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500     "
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
