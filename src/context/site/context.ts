import React from 'react'
import { SiteViewModel } from './viewmodel'

export interface ISiteContext {
  readonly viewmodel: SiteViewModel
}

export const SiteContextType = React.createContext<ISiteContext>({
  viewmodel: SiteViewModel.fromData(undefined),
})
SiteContextType.displayName = 'SiteContextType'
