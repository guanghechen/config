import { useStateValue } from '@guanghechen/react-viewmodel'
import { Computed } from '@guanghechen/viewmodel'
import mermaid from 'mermaid'
import React from 'react'
import type { ISiteContext } from './context'
import { SiteContextType } from './context'
import type { ISiteData } from './viewmodel'
import { SiteTheme, SiteViewModel } from './viewmodel'

const storageKey: string = '@guanghechen/yozora/site'

export const SiteContextProvider: React.FC<{ children: React.ReactNode }> = props => {
  const [viewmodel] = React.useState<SiteViewModel>(() => {
    const initialData: Partial<ISiteData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewmodel = SiteViewModel.fromData(initialData)
    return viewmodel
  })

  const context: ISiteContext = React.useMemo<ISiteContext>(() => ({ viewmodel }), [viewmodel])

  return (
    <React.Fragment>
      <SideEffect viewmodel={viewmodel} />
      <SiteContextType.Provider value={context}>{props.children}</SiteContextType.Provider>
    </React.Fragment>
  )
}
SiteContextProvider.displayName = 'SiteContextProvider'

const SideEffect: React.FC<{ viewmodel: SiteViewModel }> = props => {
  const { viewmodel } = props
  const theme: SiteTheme = useStateValue(viewmodel.theme$)

  React.useEffect(() => {
    const computed = Computed.fromObservables([viewmodel.theme$], () => {
      const data: ISiteData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])

  React.useEffect(() => {
    const darken = theme === SiteTheme.DARKEN
    if (darken) {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }

    mermaid.initialize({ startOnLoad: false, theme: darken ? 'dark' : 'default' })
  }, [theme])

  return <React.Fragment />
}
