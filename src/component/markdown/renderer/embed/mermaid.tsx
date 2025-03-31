import mermaid from 'mermaid'
import React from 'react'
import { ElementViewer } from '@/component/ElementViewer'
import { useMarkdownDarken } from '../../context'

interface IMermaidRendererProps {
  readonly code: string
  readonly className?: string
  readonly onClick?: () => void
}

const MermaidRenderer: React.FC<IMermaidRendererProps> = props => {
  const { code, className, onClick } = props
  const darken: boolean = useMarkdownDarken()

  const ref = React.useRef<HTMLDivElement>(null)
  const id: string = React.useId().replaceAll(/:/g, '_')

  React.useEffect(() => {
    if (!ref.current) return

    let cancelled: boolean = false
    void mermaid.render(id, code).then(({ svg }) => {
      if (!cancelled && ref.current) {
        ref.current.innerHTML = svg

        const svgElement: SVGSVGElement | null = ref.current.querySelector('svg')
        if (svgElement) {
          svgElement.style.width = '100%'
          svgElement.style.height = '100%'
          svgElement.style.maxWidth = 'unset'
          svgElement.style.maxHeight = 'unset'
        }
      }
    })

    return () => {
      cancelled = true
    }
  }, [id, code, darken])

  return <div ref={ref} className={className} onClick={onClick} />
}
MermaidRenderer.displayName = 'MermaidRenderer'

const Mermaid: React.FC<{ readonly code: string }> = props => {
  const { code } = props
  const [open, setOpen] = React.useState<boolean>(false)

  const onClick = React.useCallback((): void => {
    setOpen(true)
  }, [])

  const onClose = React.useCallback((): void => {
    setOpen(false)
  }, [])

  return (
    <React.Fragment>
      <MermaidRenderer code={code} className="cursor-pointer" onClick={onClick} />
      <ElementViewer open={open} resetOnOpen={false} onClose={onClose}>
        <MermaidRenderer code={code} className="w-[80vw] h-[80vh]" />
      </ElementViewer>
    </React.Fragment>
  )
}
Mermaid.displayName = 'CodeRendererMermaid'
export default Mermaid
