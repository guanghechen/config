import React from 'react'
import { SiteViewModel } from './viewmodel'

export interface ISiteContext {
  readonly viewmodel: SiteViewModel
}

export const SiteContextType = React.createContext<ISiteContext>({
  viewmodel: SiteViewModel.fromData({ name: 'DefaultSiteViewModel' }),
})
SiteContextType.displayName = 'SiteContextType'

export const useSiteViewmodel = (): SiteViewModel => React.useContext(SiteContextType).viewmodel
