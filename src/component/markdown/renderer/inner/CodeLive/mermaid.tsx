import mermaid from 'mermaid'
import React from 'react'

interface IProps {
  readonly code: string
}

export const Mermaid: React.FC<IProps> = props => {
  const { code } = props
  const ref = React.useRef<HTMLDivElement>(null)
  const id: string = React.useId().replaceAll(/:/g, '_')

  React.useEffect(() => {
    if (!ref.current) return

    let cancelled: boolean = false
    mermaid.initialize({ startOnLoad: false })

    void mermaid.render(id, code).then(({ svg }) => {
      if (!cancelled && ref.current) {
        ref.current.innerHTML = svg
      }
    })

    return () => {
      cancelled = true
    }
  }, [id, code])

  return <div ref={ref} />
}
