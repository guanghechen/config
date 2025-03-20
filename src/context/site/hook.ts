import type { ISetState } from '@guanghechen/react-viewmodel'
import { useSetState, useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { SiteContextType } from './context'
import type { SiteTheme, SiteViewModel } from './viewmodel'

export const useSiteViewmodel = (): SiteViewModel => React.useContext(SiteContextType).viewmodel

export const useSiteTheme = (): SiteTheme => {
  const { viewmodel } = React.useContext(SiteContextType)
  return useStateValue(viewmodel.theme$)
}

export const useSetSiteTheme = (): ISetState<SiteTheme> => {
  const { viewmodel } = React.useContext(SiteContextType)
  return useSetState(viewmodel.theme$)
}
