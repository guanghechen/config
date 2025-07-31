import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { ExcalidrawLayout } from './layout'

const ExcalidrawView: React.FC = () => {
  const siteVM = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(siteVM.theme$)

  return <ExcalidrawLayout theme={theme} />
}

ExcalidrawView.displayName = 'ExcalidrawView'

export default React.memo(ExcalidrawView, () => true)
