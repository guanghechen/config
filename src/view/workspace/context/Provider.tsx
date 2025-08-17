import { Computed, useStateValue } from '@guanghechen/react-viewmodel'
import mermaid from 'mermaid'
import React from 'react'
import type { NavigateFunction } from 'react-router-dom'
import { useNavigate, useParams } from 'react-router-dom'
import { SiteTheme, useSiteTheme } from '@/context/site'
import { useGetWorkspaces } from '@/hook/api/workspaces'
import { useSingleton } from '@/hook/useSingleton'
import { ServerCustomEventType } from '@/shared/types'
import type {
  IResponsePayloadFileChanged,
  IResponsePayloadFileSwitch,
  Mutable,
} from '@/shared/types'
import type { IWorkspaceContext } from './context'
import { WorkspaceViewContextType } from './context'
import type { IWorkspaceData } from './types'
import { WorkspaceViewViewModel } from './viewmodel'

const storageKey: string = '#/view/workspace'

interface ISideEffectProps {
  readonly viewmodel: WorkspaceViewViewModel
}

export const WorkspaceViewProvider: React.FC<{ children: React.ReactNode }> = props => {
  const { workspace_name } = useParams<{ workspace_name?: string }>()
  const viewmodel: WorkspaceViewViewModel | null = useSingleton<WorkspaceViewViewModel>(() => {
    const initialData: Mutable<Partial<IWorkspaceData>> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const usp = new URLSearchParams(window.location.search)
    const workspace: string | null = workspace_name || null
    const filepath: string | null = decodeURIComponent(usp.get('filepath') || '') || null
    return WorkspaceViewViewModel.fromData({
      workspace: workspace ?? initialData.workspace,
      filepath: filepath ?? initialData.filepath,
      workspaces: initialData.workspaces,
      filetreeKeyword: initialData.filetreeKeyword,
      filetreeMode: initialData.filetreeMode,
      sidebarVisible: initialData.sidebarVisible,
      sidebarWidth: initialData.sidebarWidth,
    })
  })
  const context: IWorkspaceContext | null = React.useMemo<IWorkspaceContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <WorkspaceViewContextType.Provider value={context}>
        {props.children}
      </WorkspaceViewContextType.Provider>
      <SideEffect viewmodel={viewmodel} />
      <HmrSideEffect viewmodel={viewmodel} />
    </React.Fragment>
  )
}
WorkspaceViewProvider.displayName = 'WorkspaceViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const HmrSideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel } = props
  const navigate = useNavigate()
  const navigateRef = React.useRef<NavigateFunction>(navigate)
  navigateRef.current = navigate

  React.useEffect(() => {
    const meta = import.meta as any
    if (!meta.hot) return

    let unsubscribed: boolean = false

    const handleFileChanged = (data: IResponsePayloadFileChanged): void => {
      if (unsubscribed) return

      const filepath: string | null = viewmodel.filepath$.getSnapshot()
      viewmodel.workspace$.next(data.workspace)
      viewmodel.filepath$.next(data.filepath, { force: true })
      if (data.filepath === filepath) viewmodel.markFilepathDirty()
    }

    const handleFileSwitch = (data: IResponsePayloadFileSwitch): void => {
      if (unsubscribed) return

      if (!data.workspace && data.filepath) {
        unsubscribed = true
        meta.hot.off(ServerCustomEventType.FILE_CHANGED, handleFileChanged)
        meta.hot.off(ServerCustomEventType.FILE_SWITCHED, handleFileSwitch)
        void navigateRef.current(`/file?filepath=${encodeURIComponent(data.filepath)}`)
        return
      }

      const workspace: string | null = viewmodel.workspace$.getSnapshot()
      const filepath: string | null = viewmodel.filepath$.getSnapshot()
      if (data.workspace !== workspace) viewmodel.workspace$.next(data.workspace)
      if (data.filepath !== filepath) viewmodel.filepath$.next(data.filepath)
      else viewmodel.markFilepathDirty()

      window.postMessage({
        action: '@@tsuki-event@@',
        tsuki: {
          event: 'focus_me',
          payload: {},
        },
      })
    }

    meta.hot.on(ServerCustomEventType.FILE_CHANGED, handleFileChanged)
    meta.hot.on(ServerCustomEventType.FILE_SWITCHED, handleFileSwitch)
    return () => {
      unsubscribed = true
      meta.hot.off(ServerCustomEventType.FILE_CHANGED, handleFileChanged)
      meta.hot.off(ServerCustomEventType.FILE_SWITCHED, handleFileSwitch)
    }
  }, [viewmodel])

  return <React.Fragment />
}
HmrSideEffect.displayName = 'WorkspaceViewHmrSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel } = props
  const theme: SiteTheme = useSiteTheme()

  const workspace: string | null = useStateValue(viewmodel.workspace$)
  const filepath: string | null = useStateValue(viewmodel.filepath$)
  const workspacesDirtyTick: number = useStateValue(viewmodel.workspacesDirtyTick$)
  const { workspaces } = useGetWorkspaces(workspacesDirtyTick)

  React.useEffect(() => {
    const computed = Computed.fromObservables(
      [
        viewmodel.filepath$,
        viewmodel.workspace$,
        viewmodel.workspaces$,
        viewmodel.filetreeMode$,
        viewmodel.sidebarWidth$,
        viewmodel.sidebarVisible$,
      ],
      () => {
        const data: IWorkspaceData = viewmodel.dump()
        window.localStorage.setItem(storageKey, JSON.stringify(data))
      },
    )
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])

  React.useEffect(() => {
    viewmodel.workspaces$.next(workspaces)
  }, [viewmodel, workspaces])

  React.useEffect(() => {
    const usp = new URLSearchParams(window.location.search)
    usp.delete('workspace')
    usp.delete('filepath')

    if (workspace) usp.set('workspace', encodeURIComponent(workspace))
    if (filepath) usp.set('filepath', encodeURIComponent(filepath))
    const newUrl = `${window.location.pathname}?${usp.toString()}`
    window.history.replaceState(null, '', newUrl)
  }, [workspace, filepath])

  React.useEffect(() => {
    const darken = theme === SiteTheme.DARKEN
    mermaid.initialize({ startOnLoad: false, theme: darken ? 'dark' : 'default' })
  }, [theme])

  return <React.Fragment />
}

SideEffect.displayName = 'WorkspaceViewSideEffect'
