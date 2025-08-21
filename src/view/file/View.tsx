import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { MarkdownTopProvider } from '@/component/markdown'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { Composer } from './Composer'
import { FileViewProvider } from './context'

export const FileView: React.FC = () => {
  const site = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(site.theme$)

  return (
    <FileViewProvider>
      <MarkdownTopProvider theme={theme}>
        <Composer />
      </MarkdownTopProvider>
    </FileViewProvider>
  )
}

FileView.displayName = 'FileView'
