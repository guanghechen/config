import { useEventCallback } from '@guanghechen/react-hooks'
import { Computed, useStateValue } from '@guanghechen/react-viewmodel'
import mermaid from 'mermaid'
import React from 'react'
import { useWorkspaces } from '@/hook/useWorkspaces'
import { ServerCustomEventType } from '@/shared/types'
import type {
  IResponsePayloadFileChanged,
  IResponsePayloadFileSwitch,
  Mutable,
} from '@/shared/types'
import { SiteTheme, useSiteTheme } from '../site'
import type { IWorkspaceContext } from './context'
import { WorkspaceContextType } from './context'
import type { IWorkspaceData } from './types'
import { WorkspaceViewModel } from './viewmodel'

const storageKey: string = '@guanghechen/yozora/workspace'

interface ISideEffectProps {
  readonly viewmodel: WorkspaceViewModel
}

export const WorkspaceContextProvider: React.FC<{ children: React.ReactNode }> = props => {
  const [viewmodel] = React.useState<WorkspaceViewModel>(() => {
    const initialData: Mutable<Partial<IWorkspaceData>> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const usp = new URLSearchParams(window.location.search)
    const workspace: string | null = decodeURIComponent(usp.get('workspace') || '') || null
    const filepath: string | null = decodeURIComponent(usp.get('filepath') || '') || null

    if (workspace) initialData.workspace = workspace
    if (filepath) initialData.filepath = filepath
    const viewmodel = WorkspaceViewModel.fromData(initialData)
    return viewmodel
  })

  const context: IWorkspaceContext = React.useMemo<IWorkspaceContext>(
    () => ({ viewmodel }),
    [viewmodel],
  )

  return (
    <React.Fragment>
      <PersistSideEffect viewmodel={viewmodel} />
      <SideEffect viewmodel={viewmodel} />
      <MermaidSideEffect viewmodel={viewmodel} />
      <WorkspaceContextType.Provider value={context}>
        {props.children}
      </WorkspaceContextType.Provider>
    </React.Fragment>
  )
}
WorkspaceContextProvider.displayName = 'WorkspaceContextProvider'

const PersistSideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel } = props

  React.useEffect(() => {
    const computed = Computed.fromObservables(
      [
        viewmodel.filepath$,
        viewmodel.workspace$,
        viewmodel.workspaces$,
        viewmodel.filetreeMode$,
        viewmodel.jsonMode$,
        viewmodel.markdownMode$,
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

  return <React.Fragment />
}
PersistSideEffect.displayName = 'WorkspacePersistSideEffect'

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel } = props
  const workspace: string | null = useStateValue(viewmodel.workspace$)
  const filepath: string | null = useStateValue(viewmodel.filepath$)
  const workspacesDirtyTick: number = useStateValue(viewmodel.workspacesDirtyTick$)
  const { workspaces } = useWorkspaces(workspacesDirtyTick)

  const hmr = useEventCallback((): void => {
    const meta = import.meta as any
    if (meta.hot) {
      meta.hot.on(ServerCustomEventType.FILE_CHANGED, (data: IResponsePayloadFileChanged): void => {
        viewmodel.workspace$.next(data.workspace)
        viewmodel.filepath$.next(data.filepath, { force: true })
        if (data.filepath === filepath) viewmodel.markFilepathDirty()
      })
      meta.hot.on(ServerCustomEventType.FILE_SWITCHED, (data: IResponsePayloadFileSwitch): void => {
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
      })
    }
  })

  React.useEffect(() => {
    viewmodel.workspaces$.next(workspaces)
  }, [viewmodel, workspaces])

  React.useEffect(() => {
    hmr()
  }, [hmr])

  React.useEffect(() => {
    const usp = new URLSearchParams(window.location.search)
    usp.delete('workspace')
    usp.delete('filepath')

    if (workspace) usp.set('workspace', encodeURIComponent(workspace))
    if (filepath) usp.set('filepath', encodeURIComponent(filepath))
    const newUrl = `${window.location.pathname}?${usp.toString()}`
    window.history.replaceState(null, '', newUrl)
  }, [workspace, filepath])

  return <React.Fragment />
}

const MermaidSideEffect: React.FC<ISideEffectProps> = () => {
  const theme: SiteTheme = useSiteTheme()

  React.useEffect(() => {
    const darken = theme === SiteTheme.DARKEN
    mermaid.initialize({ startOnLoad: false, theme: darken ? 'dark' : 'default' })
  }, [theme])

  return <React.Fragment />
}
