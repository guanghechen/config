import { useStateValue } from '@guanghechen/react-viewmodel'
import { type Root, RootType } from '@yozora/ast'
import React from 'react'
import { MarkdownProvider } from '@/component/markdown'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { ExcalidrawLayout } from './layout'

const emptyAst: Root = {
  type: RootType,
  children: [],
}

const ExcalidrawView: React.FC = () => {
  const siteVM = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(siteVM.theme$)

  return (
    <MarkdownProvider ast={emptyAst} theme={theme}>
      <ExcalidrawLayout />
    </MarkdownProvider>
  )
}

ExcalidrawView.displayName = 'ExcalidrawView'

export default React.memo(ExcalidrawView, () => true)
