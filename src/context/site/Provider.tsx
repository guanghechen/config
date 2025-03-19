import { useStateValue } from '@guanghechen/react-viewmodel'
import { Computed } from '@guanghechen/viewmodel'
import mermaid from 'mermaid'
import React from 'react'
import { useWorkspaces } from '@/hook/useWorkspaces'
import { ServerCustomEventType } from '@/shared/types'
import type { IResponsePayloadFileChanged, IResponsePayloadFileSwitch } from '@/shared/types'
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
    viewmodel.onSearchChange()
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
  const workspace: string | null = useStateValue(viewmodel.workspace$)
  const filepath: string | null = useStateValue(viewmodel.filepath$)
  const workspacesDirtyTick: number = useStateValue(viewmodel.workspacesDirtyTick$)

  const { workspaces } = useWorkspaces(workspacesDirtyTick)

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
    const handlePopState = (): void => {
      viewmodel.onSearchChange()
    }

    window.addEventListener('popstate', handlePopState)
    return () => window.removeEventListener('popstate', handlePopState)
  }, [viewmodel])

  React.useEffect(() => {
    viewmodel.workspaces$.next(workspaces)
  }, [viewmodel, workspaces])

  React.useEffect(() => {
    const meta = import.meta as any
    if (meta.hot) {
      meta.hot.on(ServerCustomEventType.FILE_CHANGED, (data: IResponsePayloadFileChanged): void => {
        viewmodel.filepath$.next(data.filepath)
      })
      meta.hot.on(ServerCustomEventType.FILE_SWITCHED, (data: IResponsePayloadFileSwitch): void => {
        const workspace: string | null = viewmodel.workspace$.getSnapshot()
        const filepath: string | null = viewmodel.filepath$.getSnapshot()
        if (data.workspace !== workspace) viewmodel.workspace$.next(data.workspace)
        if (data.filepath !== filepath) viewmodel.filepath$.next(data.filepath)
        else viewmodel.markFilepathDirty()
      })
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

  React.useEffect(() => {
    const usp = new URLSearchParams(window.location.search)
    if (workspace) usp.set('workspace', encodeURIComponent(workspace))
    if (filepath) usp.set('filepath', encodeURIComponent(filepath))
    const newUrl = `${window.location.pathname}?${usp.toString()}`
    window.history.replaceState(null, '', newUrl)
  }, [workspace, filepath])

  return <React.Fragment />
}
