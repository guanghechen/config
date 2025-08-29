import { useStateValue, useViewModel } from '@guanghechen/react-viewmodel'
import mermaid from 'mermaid'
import React from 'react'
import type { NavigateFunction } from 'react-router-dom'
import { useNavigate, useParams } from 'react-router-dom'
import { SiteTheme, useSiteTheme } from '@/context/site'
import { useGetWorkspaces } from '@/hook/api/workspaces'
import { usePersist } from '@/hook/usePersist'
import { ServerCustomEventType } from '@/shared/types'
import type { IResponsePayloadFileChanged, IResponsePayloadFileSwitch } from '@/shared/types'
import type { IWorkspaceContext } from './context'
import { WorkspaceViewContextType } from './context'
import type { IWorkspaceViewData } from './types'
import { WorkspaceViewViewModel } from './viewmodel'

const storageKey: string = '#/view/workspace'

export const WorkspaceViewProvider: React.FC<{ children: React.ReactNode }> = props => {
  const { workspace_name } = useParams<{ workspace_name?: string }>()
  const viewmodel: WorkspaceViewViewModel | null = useViewModel<WorkspaceViewViewModel>(() => {
    const rawViewData: Partial<IWorkspaceViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const usp = new URLSearchParams(window.location.search)
    const workspace: string | null = workspace_name || null
    const filepath: string | null = decodeURIComponent(usp.get('filepath') || '') || null

    const viewData: IWorkspaceViewData = WorkspaceViewViewModel.normalize(rawViewData)
    return new WorkspaceViewViewModel({
      workspace: workspace ?? viewData.workspace,
      filepath: filepath ?? viewData.filepath,
      workspaces: viewData.workspaces,
      filetreeKeyword: viewData.filetreeKeyword,
      filetreeMode: viewData.filetreeMode,
      sidebarVisible: viewData.sidebarVisible,
      sidebarWidth: viewData.sidebarWidth,
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
      <SideEffect viewmodel={viewmodel} workspace={workspace_name ?? null} />
    </React.Fragment>
  )
}
WorkspaceViewProvider.displayName = 'WorkspaceViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: WorkspaceViewViewModel
  readonly workspace: string | null
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace } = props

  usePersist(viewmodel, storageKey, [
    viewmodel.filepath$,
    viewmodel.workspace$,
    viewmodel.workspaces$,
    viewmodel.filetreeMode$,
    viewmodel.sidebarWidth$,
    viewmodel.sidebarVisible$,
  ])
  useHMR(viewmodel)
  useSyncProps(viewmodel, workspace)
  useMermaid()

  return <React.Fragment />
}

SideEffect.displayName = 'WorkspaceViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const useHMR = (viewmodel: WorkspaceViewViewModel): void => {
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
      const workspace: string | null = viewmodel.workspace$.getSnapshot()
      if (data.workspace === workspace && data.filepath === filepath) viewmodel.markFilepathDirty()
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
}

const useSyncProps = (viewmodel: WorkspaceViewViewModel, workspace: string | null): void => {
  const workspacesDirtyTick: number = useStateValue(viewmodel.workspacesDirtyTick$)
  const { workspaces } = useGetWorkspaces(workspacesDirtyTick)
  const filepath: string | null = useStateValue(viewmodel.filepath$)

  React.useEffect(() => {
    viewmodel.workspaces$.next(workspaces)
  }, [viewmodel, workspaces])

  React.useEffect(() => {
    if (workspace !== viewmodel.workspace$.getSnapshot()) {
      viewmodel.workspace$.next(workspace)
      viewmodel.filepath$.next(null)
    }
  }, [viewmodel, workspace])

  React.useEffect(() => {
    const usp = new URLSearchParams(window.location.search)
    usp.delete('workspace')
    usp.delete('filepath')
    if (filepath) usp.set('filepath', encodeURIComponent(filepath))

    const pathname: string = window.location.pathname
    const search: string = usp.toString()
    const nextUrl: string = search ? `${pathname}?${usp.toString()}` : pathname
    window.history.replaceState(null, '', nextUrl)
  }, [filepath])
}

const useMermaid = (): void => {
  const theme: SiteTheme = useSiteTheme()

  React.useEffect(() => {
    const darken = theme === SiteTheme.DARKEN
    mermaid.initialize({ startOnLoad: false, theme: darken ? 'dark' : 'default' })
  }, [theme])
}
