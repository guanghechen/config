import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { MarkdownTopProvider } from '@/component/markdown'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { Composer } from './Composer'
import { WhiteboardViewProvider } from './context'

export const WhiteboardView: React.FC = () => {
  const site = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(site.theme$)

  return (
    <WhiteboardViewProvider>
      <MarkdownTopProvider theme={theme}>
        <Composer />
      </MarkdownTopProvider>
    </WhiteboardViewProvider>
  )
}

WhiteboardView.displayName = 'WhiteboardView'
