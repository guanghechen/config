import mermaid from 'mermaid'
import React from 'react'

interface IProps {
  readonly code: string
}

export const Mermaid: React.FC<IProps> = props => {
  const { code } = props
  const containerRef = React.useRef<HTMLDivElement>(null)

  React.useEffect(() => {
    if (!containerRef.current) return

    let cancelled: boolean = false
    mermaid.initialize({ startOnLoad: false })

    void mermaid.render('mermaid-diagram', code).then(({ svg }) => {
      if (!cancelled && containerRef.current) {
        containerRef.current.innerHTML = svg
      }
    })

    return () => {
      cancelled = true
    }
  }, [code])

  return <div ref={containerRef} />
}
