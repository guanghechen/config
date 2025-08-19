import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { MarkdownTopProvider } from '@/component/markdown'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { Composer } from './Composer'
import { WorkspaceViewProvider } from './context'
import './style.css'

export const WorkspaceView: React.FC = () => {
  const siteVM = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(siteVM.theme$)

  return (
    <WorkspaceViewProvider>
      <MarkdownTopProvider theme={theme}>
        <Composer />
      </MarkdownTopProvider>
    </WorkspaceViewProvider>
  )
}

WorkspaceView.displayName = 'WorkspaceView'
