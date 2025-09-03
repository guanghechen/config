import { useStateValue } from '@guanghechen/react-viewmodel'
import mermaid from 'mermaid'
import React from 'react'
import { SiteTheme, useSiteViewmodel } from '@/context/site'

export const useMermaidSyncThemeEffect = (): void => {
  const viewmodel = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(viewmodel.theme$)

  React.useEffect(() => {
    const darken = theme === SiteTheme.DARKEN
    mermaid.initialize({ startOnLoad: false, theme: darken ? 'dark' : 'default' })
  }, [theme])
}
