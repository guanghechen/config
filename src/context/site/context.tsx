import { Computed } from '@guanghechen/viewmodel'
import React from 'react'
import type { ISiteContext, ISiteData, ISiteViewModel } from './types'
import { SiteViewModel } from './viewmodel'

const storageKey: string = '@guanghechen/yozora/site'

const SiteContextType = React.createContext<ISiteContext>({
  viewmodel: SiteViewModel.fromData(undefined),
})
SiteContextType.displayName = 'SiteContextType'

export const useSiteContext = (): ISiteContext => React.useContext(SiteContextType)

export const SiteContextProvider: React.FC<{ children: React.ReactNode }> = props => {
  const [viewmodel] = React.useState<ISiteViewModel>(() => {
    const initialData: Partial<ISiteData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewmodel = SiteViewModel.fromData(initialData)
    return viewmodel
  })

  const context: ISiteContext = React.useMemo<ISiteContext>(() => ({ viewmodel }), [viewmodel])

  React.useEffect(() => {
    const computed = Computed.fromObservables([viewmodel.theme$], () => {
      const data: ISiteData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])

  return <SiteContextType.Provider value={context}>{props.children}</SiteContextType.Provider>
}
