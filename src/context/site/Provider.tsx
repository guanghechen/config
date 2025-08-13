import { useStateValue } from '@guanghechen/react-viewmodel'
import { Computed } from '@guanghechen/viewmodel'
import React from 'react'
import { useSingleton } from '@/hook/useSingleton'
import type { ISiteContext } from './context'
import { SiteContextType } from './context'
import type { ISiteData } from './viewmodel'
import { SiteTheme, SiteViewModel } from './viewmodel'

const storageKey: string = '#/context/site'

interface ISideEffectProps {
  readonly viewmodel: SiteViewModel
}

export const SiteContextProvider: React.FC<{ children: React.ReactNode }> = props => {
  const viewmodel: SiteViewModel | null = useSingleton<SiteViewModel>(() => {
    const initialData: Partial<ISiteData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return SiteViewModel.fromData(initialData)
  })
  const context: ISiteContext | null = React.useMemo<ISiteContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <SiteContextType.Provider value={context}>{props.children}</SiteContextType.Provider>
      <SideEffect viewmodel={viewmodel} />
    </React.Fragment>
  )
}
SiteContextProvider.displayName = 'SiteContextProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const SideEffect: React.FC<ISideEffectProps> = props => {
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
  }, [theme])

  return <React.Fragment />
}
SideEffect.displayName = 'SiteContextSideEffect'
