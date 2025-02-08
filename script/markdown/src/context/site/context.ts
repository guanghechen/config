import React from 'react'
import type { ISiteContext } from './types'
import { SiteTheme } from './types'
import { SiteViewModel } from './viewmodel'

const SiteContextType = React.createContext<ISiteContext>({
  viewmodel: new SiteViewModel({
    theme: SiteTheme.LIGHTEN,
  }),
})
SiteContextType.displayName = 'SiteContextType'

export const SiteContextProvider = SiteContextType.Provider
export const useSiteContext = (): ISiteContext => React.useContext(SiteContextType)
