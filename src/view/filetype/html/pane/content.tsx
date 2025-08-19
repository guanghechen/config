import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { toSearch } from '@/shared/util'
import { useHtmlViewViewModel } from '../context'

interface IProps {
  readonly workspace: string | null
}

export const ContentPane: React.FC<IProps> = props => {
  const { workspace } = props
  const viewmodel = useHtmlViewViewModel()
  const filepath = useStateValue(viewmodel.filepath$)
  const tailwindEnabled: boolean = useStateValue(viewmodel.enableTailwindcss$)

  const iframeRef = React.useRef<HTMLIFrameElement>(null)

  const url = React.useMemo<string>(() => {
    const search = toSearch({ filepath, workspace })
    return `/api/file${search}`
  }, [filepath, workspace])

  const injectTailwindCSS = React.useCallback(() => {
    const iframe = iframeRef.current
    if (!iframe || !iframe.contentDocument) return

    const doc = iframe.contentDocument
    const existingTailwind = doc.getElementById('injected-tailwind-css')

    if (tailwindEnabled && !existingTailwind) {
      const script = doc.createElement('script')
      script.id = 'injected-tailwind-css'
      script.src = 'https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4'
      doc.head.appendChild(script)
    } else if (!tailwindEnabled && existingTailwind) {
      existingTailwind.remove()
      const currentSrc = iframe.src
      iframe.src = 'about:blank'
      setTimeout(() => {
        iframe.src = currentSrc
      }, 50)
    }
  }, [tailwindEnabled])

  const handleIframeLoad = React.useCallback(() => {
    injectTailwindCSS()
  }, [injectTailwindCSS])

  React.useEffect(() => {
    injectTailwindCSS()
  }, [injectTailwindCSS])

  return (
    <iframe
      ref={iframeRef}
      src={url}
      title={filepath || 'HTML file'}
      className="h-full w-full border-none"
      sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-popups-to-escape-sandbox"
      onLoad={handleIframeLoad}
    />
  )
}

ContentPane.displayName = 'HtmlViewContentPane'
