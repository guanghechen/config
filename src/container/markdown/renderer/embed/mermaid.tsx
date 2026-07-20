import mermaid from 'mermaid'
import React from 'react'
import { ElementViewer } from '@/common/component/ElementViewer'
import { useMarkdownDarken } from '../../hook/useMarkdownDarken'

interface IMermaidRendererProps {
  readonly code: string
}

interface IMermaidRenderRequest {
  readonly code: string
  readonly darken: boolean
}

interface IMermaidRenderError {
  readonly request: IMermaidRenderRequest
  readonly message: string
}

const MermaidRenderer: React.FC<IMermaidRendererProps> = props => {
  const { code } = props
  const darken: boolean = useMarkdownDarken()
  const request = React.useMemo<IMermaidRenderRequest>(() => ({ code, darken }), [code, darken])
  const [renderError, setRenderError] = React.useState<IMermaidRenderError | null>(null)

  const ref = React.useRef<HTMLDivElement>(null)
  const id: string = React.useId().replaceAll(/:/g, '_')
  const renderSequenceRef = React.useRef<number>(0)
  const errorMessage: string | null = renderError?.request === request ? renderError.message : null

  React.useEffect(() => {
    if (!ref.current) return

    let cancelled: boolean = false
    renderSequenceRef.current += 1

    const renderId: string = `${id}_${renderSequenceRef.current}`
    const renderContainer: HTMLDivElement = document.createElement('div')
    renderContainer.ariaHidden = 'true'
    renderContainer.style.position = 'fixed'
    renderContainer.style.inset = '0'
    renderContainer.style.visibility = 'hidden'
    renderContainer.style.pointerEvents = 'none'
    document.body.append(renderContainer)

    // Isolate Mermaid's temporary/error DOM while preserving the last successful visible SVG.
    void mermaid
      .render(renderId, request.code, renderContainer)
      .then(({ svg }) => {
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
      .catch((error: unknown) => {
        if (!cancelled) {
          const message: string =
            (error instanceof Error ? error.message || error.name : String(error)) ||
            'Unknown error'
          setRenderError({ request, message })
        }
      })
      .finally(() => {
        renderContainer.remove()
      })

    return () => {
      cancelled = true
    }
  }, [id, request])

  return (
    <div className="size-full p-2">
      {errorMessage ? (
        <div className="size-full overflow-auto text-sm text-red-600 dark:text-red-400">
          <pre role="alert" className="whitespace-pre-wrap">
            {`Failed to render Mermaid diagram:\n${errorMessage}`}
          </pre>
          <div className="mt-4 font-semibold">Mermaid source</div>
          <pre aria-label="Mermaid source" className="whitespace-pre-wrap">
            {code}
          </pre>
        </div>
      ) : null}
      <div ref={ref} className={errorMessage ? 'hidden' : 'size-full'} />
    </div>
  )
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
