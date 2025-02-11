import { MathJaxProvider } from '@yozora/react-mathjax'
import React from 'react'
import { createRoot } from 'react-dom/client'
import { MarkdownView } from '@/view/markdown'
import type { ISiteContext } from './context/site'
import { SiteContextProvider, SiteTheme, SiteViewModel } from './context/site'

const App: React.FC = () => {
  return (
    <React.StrictMode>
      <React.Suspense fallback={<div>loading...</div>}>
        <Context>
          <MarkdownView />
        </Context>
      </React.Suspense>
    </React.StrictMode>
  )
}

const Context: React.FC<React.PropsWithChildren> = props => {
  const [siteContext] = React.useState<ISiteContext>(() => {
    const viewmodel = new SiteViewModel({
      theme: SiteTheme.LIGHTEN,
    })
    return { viewmodel }
  })

  return (
    <MathJaxProvider>
      <SiteContextProvider value={siteContext}>{props.children}</SiteContextProvider>
    </MathJaxProvider>
  )
}

createRoot(document.getElementById('root')!).render(<App />)
