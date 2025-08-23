import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useHtmlViewViewModel } from '../context'

export const ContentPane: React.FC = () => {
  const viewmodel = useHtmlViewViewModel()
  const content: string | null = useStateValue(viewmodel.content$)
  const tailwindEnabled: boolean = useStateValue(viewmodel.enableTailwindcss$)

  const iframeRef = React.useRef<HTMLIFrameElement>(null)

  const injectTailwindCSS = useEventCallback(() => {
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
    }
  })

  const handleIframeLoad = React.useCallback(() => {
    injectTailwindCSS()
  }, [injectTailwindCSS])

  React.useEffect(() => {
    injectTailwindCSS()
  }, [injectTailwindCSS])

  if (!content) {
    return <div className="p-4 text-gray-500">No content provided.</div>
  }

  return (
    <iframe
      ref={iframeRef}
      srcDoc={content}
      title={'HTML file'}
      className="h-full w-full border-none"
      sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-popups-to-escape-sandbox"
      onLoad={handleIframeLoad}
    />
  )
}

ContentPane.displayName = 'HtmlViewContentPane'
