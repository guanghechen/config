import React from 'react'
import { SiteContextType } from './context'
import type { SiteViewModel } from './viewmodel'

export const useSiteViewmodel = (): SiteViewModel => React.useContext(SiteContextType).viewmodel
