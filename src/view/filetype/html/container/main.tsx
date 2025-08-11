import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { toSearch } from '@/util/url'
import { useHtmlViewViewModel } from '../context'

export const HtmlMain: React.FC = () => {
  const viewmodel = useHtmlViewViewModel()
  const filepath = useStateValue(viewmodel.filepath$)
  const workspace = useStateValue(viewmodel.workspace$)

  const url = React.useMemo<string>(() => {
    const search = toSearch({ filepath, workspace })
    return `/api/file${search}`
  }, [filepath, workspace])

  return (
    <div className="relative h-full w-full">
      <iframe
        src={url}
        title={filepath || 'HTML file'}
        className="h-full w-full border-none"
        sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-popups-to-escape-sandbox"
      />
    </div>
  )
}

HtmlMain.displayName = 'HtmlMain'
