import mermaid from 'mermaid'
import React from 'react'
import { useMarkdownDarken } from '../../context'

interface IProps {
  readonly code: string
}

const Mermaid: React.FC<IProps> = props => {
  const { code } = props

  const darken: boolean = useMarkdownDarken()

  const ref = React.useRef<HTMLDivElement>(null)
  const id: string = React.useId().replaceAll(/:/g, '_')

  React.useEffect(() => {
    if (!ref.current) return

    let cancelled: boolean = false

    void mermaid.render(id, code).then(({ svg }) => {
      if (!cancelled && ref.current) {
        ref.current.innerHTML = svg
      }
    })

    return () => {
      cancelled = true
    }
  }, [id, code, darken])

  return <div ref={ref} />
}
Mermaid.displayName = 'CodeRendererMermaid'

export default Mermaid
