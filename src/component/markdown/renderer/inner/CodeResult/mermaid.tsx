import { useStateValue } from '@guanghechen/react-viewmodel'
import mermaid from 'mermaid'
import React from 'react'
import { useMarkdownViewmodel } from '@/component/markdown/context'

interface IProps {
  readonly code: string
}

export const Mermaid: React.FC<IProps> = props => {
  const { code } = props

  const viewmodel = useMarkdownViewmodel()
  const theme = useStateValue(viewmodel.themeScheme$)

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
  }, [id, code, theme])

  return <div ref={ref} />
}
