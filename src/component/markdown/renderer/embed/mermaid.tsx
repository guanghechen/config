import mermaid from 'mermaid'
import React from 'react'
import { ElementViewer } from '@/component/ElementViewer'
import { useMarkdownDarken } from '../../context'

interface IMermaidRendererProps {
  readonly code: string
}

const MermaidRenderer: React.FC<IMermaidRendererProps> = props => {
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

  return <div ref={ref} className="size-full p-2" />
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
      <div
        className="cursor-pointer w-full h-full flex items-center justify-center"
        onClick={onClick}
      >
        <MermaidRenderer code={code} />
      </div>
      <ElementViewer open={open} resetOnOpen={false} onClose={onClose}>
        <div className="w-[80vw] h-[80vh]">
          <MermaidRenderer code={code} />
        </div>
      </ElementViewer>
    </React.Fragment>
  )
}
Mermaid.displayName = 'CodeRendererMermaid'
export default Mermaid
