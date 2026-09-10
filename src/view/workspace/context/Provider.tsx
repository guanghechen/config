import { useStateValue, useViewModel } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { NavigateFunction } from 'react-router-dom'
import { useLocation, useNavigate, useParams } from 'react-router-dom'
import { usePersistAsync } from '@/common/hook/usePersistAsync'
import {
  normalizeAbsoluteFilepath,
  readAbsoluteSearchParam,
  resolveWorkspaceFilepath,
  selectWorkspaceRoot,
} from '@/common/util/path'
import { universalStorage } from '@/common/util/storage'
import { useMermaidSyncThemeEffect } from '@/hook/useMermaidSyncThemeEffect'
import { workspaceController } from '@/shared/api'
import { ServerCustomEventType } from '@/shared/types'
import type {
  ILegacyWorkspace,
  IResponsePayloadFileChanged,
  IResponsePayloadFileSwitch,
  IWorkspaceConfig,
} from '@/shared/types'
import type { IWorkspaceContext } from './context'
import { WorkspaceViewContextType } from './context'
import type { IWorkspaceViewData } from './types'
import { WorkspaceViewViewModel } from './viewmodel'

const storageKey: string = '#/view/workspace'

interface ILegacyWorkspaceViewData extends Partial<IWorkspaceViewData> {
  readonly workspace?: unknown
}

const EMPTY_WORKSPACE_CONFIG: IWorkspaceConfig = {
  defaultWorkspaceRoots: [],
  legacyWorkspaces: [],
}

export const WorkspaceViewProvider: React.FC<{ children: React.ReactNode }> = props => {
  const { workspace_name: legacyWorkspaceTag } = useParams<{ workspace_name?: string }>()
  const location = useLocation()
  const viewmodel: WorkspaceViewViewModel | null = useViewModel<WorkspaceViewViewModel>(
    async () => {
      const [rawViewData, workspaceConfigResult] = await Promise.all([
        universalStorage.getContext<ILegacyWorkspaceViewData>(storageKey),
        workspaceController
          .list()
          .then(config => ({ config, loaded: true }))
          .catch(error => {
            console.warn('Failed to load workspace configuration:', error)
            return { config: EMPTY_WORKSPACE_CONFIG, loaded: false }
          }),
      ])
      const workspaceConfig = workspaceConfigResult.config
      const storedData = WorkspaceViewViewModel.normalize(rawViewData)
      const workspaceRoots = storedData.workspaceRootsInitialized
        ? storedData.workspaceRoots
        : workspaceConfigResult.loaded
          ? normalizeWorkspaceRoots(workspaceConfig.defaultWorkspaceRoots)
          : storedData.workspaceRoots
      const legacyStoredRoot = findLegacyWorkspaceRoot(
        typeof rawViewData?.workspace === 'string' ? rawViewData.workspace : null,
        workspaceConfig.legacyWorkspaces,
      )
      const storedRoot = storedData.workspaceRoot ?? legacyStoredRoot
      const route = resolveWorkspaceRoute(
        location.pathname,
        location.search,
        legacyWorkspaceTag,
        workspaceConfig.legacyWorkspaces,
      )
      const workspaceRoot = route.hasWorkspaceRoot
        ? route.workspaceRoot
        : (storedRoot ?? workspaceRoots[0] ?? null)
      const storedFilepath =
        legacyStoredRoot && storedData.filepath
          ? resolveLegacyWorkspaceFilepath(legacyStoredRoot, storedData.filepath)
          : storedData.filepath
      const filepath = route.hasFilepath
        ? route.filepath
        : workspaceRoot === storedRoot
          ? storedFilepath
          : null

      return new WorkspaceViewViewModel({
        workspaceRoot,
        workspaceRoots,
        workspaceRootsInitialized:
          storedData.workspaceRootsInitialized || workspaceConfigResult.loaded,
        legacyWorkspaces: workspaceConfig.legacyWorkspaces,
        workspaceConfigLoaded: workspaceConfigResult.loaded,
        workspaceError:
          !workspaceConfigResult.loaded && legacyWorkspaceTag
            ? 'Failed to load workspace configuration.'
            : route.error,
        filepath,
        filetreeKeyword: storedData.filetreeKeyword,
        filetreeMode: storedData.filetreeMode,
        sidebarVisible: storedData.sidebarVisible,
        sidebarWidth: storedData.sidebarWidth,
      })
    },
  )

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
    </React.Fragment>
  )
}
WorkspaceViewProvider.displayName = 'WorkspaceViewProvider'

interface ISideEffectProps {
  readonly viewmodel: WorkspaceViewViewModel
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel } = props

  usePersistAsync(viewmodel, storageKey, [
    viewmodel.filepath$,
    viewmodel.workspaceRoot$,
    viewmodel.workspaceRoots$,
    viewmodel.workspaceRootsInitialized$,
    viewmodel.filetreeMode$,
    viewmodel.sidebarWidth$,
    viewmodel.sidebarVisible$,
  ])
  useHMR(viewmodel)
  useSyncUrl(viewmodel)
  useMermaidSyncThemeEffect()

  return <React.Fragment />
}

SideEffect.displayName = 'WorkspaceViewSideEffect'

const useHMR = (viewmodel: WorkspaceViewViewModel): void => {
  const navigate = useNavigate()
  const navigateRef = React.useRef<NavigateFunction>(navigate)
  navigateRef.current = navigate

  React.useEffect(() => {
    const meta = import.meta as any
    let unsubscribed: boolean = false

    const handleFileChanged = (data: IResponsePayloadFileChanged): void => {
      if (unsubscribed) return
      if (normalizeAbsoluteFilepath(data.filepath) === viewmodel.filepath$.getSnapshot()) {
        viewmodel.markFilepathDirty()
      }
    }

    const handleFileSwitchAsk = (data: IResponsePayloadFileSwitch): void => {
      if (unsubscribed) return
      window.postMessage({
        action: '@@tsuki-current@@',
        tsuki: { event: 'file_switch', payload: { filepath: data.filepath } },
      })
    }

    const handleFileSwitch = (data: IResponsePayloadFileSwitch): void => {
      if (unsubscribed || !data.filepath) return
      const targetFilepath = normalizeAbsoluteFilepath(data.filepath)
      if (!targetFilepath) return

      const currentRoot = viewmodel.workspaceRoot$.getSnapshot()
      const workspaceRoots = viewmodel.workspaceRoots$.getSnapshot()
      const targetRoot = selectWorkspaceRoot(
        targetFilepath,
        currentRoot ? [currentRoot, ...workspaceRoots] : workspaceRoots,
      )
      if (!targetRoot) {
        unsubscribed = true
        meta.hot?.off(ServerCustomEventType.FILE_CHANGED, handleFileChanged)
        meta.hot?.off(ServerCustomEventType.FILE_SWITCH_ASK, handleFileSwitchAsk)
        void navigateRef.current(createFileUrl(targetFilepath))
        return
      }

      if (targetRoot !== currentRoot) viewmodel.workspaceRoot$.next(targetRoot)
      if (targetFilepath !== viewmodel.filepath$.getSnapshot()) {
        viewmodel.filepath$.next(targetFilepath)
      } else {
        viewmodel.markFilepathDirty()
      }

      window.postMessage({ action: '@@tsuki-current@@', tsuki: { event: 'focus_me', payload: {} } })
    }

    const handleWindowMessage = (event: MessageEvent): void => {
      if (unsubscribed || event.source !== window || !event.data) return
      if (event.data.action === 'FILE_SWITCH') handleFileSwitch(event.data.payload)
    }

    meta.hot?.on(ServerCustomEventType.FILE_CHANGED, handleFileChanged)
    meta.hot?.on(ServerCustomEventType.FILE_SWITCH_ASK, handleFileSwitchAsk)
    window.addEventListener('message', handleWindowMessage)

    return () => {
      unsubscribed = true
      meta.hot?.off(ServerCustomEventType.FILE_CHANGED, handleFileChanged)
      meta.hot?.off(ServerCustomEventType.FILE_SWITCH_ASK, handleFileSwitchAsk)
      window.removeEventListener('message', handleWindowMessage)
    }
  }, [viewmodel])
}

const useSyncUrl = (viewmodel: WorkspaceViewViewModel): void => {
  const navigate = useNavigate()
  const location = useLocation()
  const workspaceRoot = useStateValue(viewmodel.workspaceRoot$)
  const workspaceRoots = useStateValue(viewmodel.workspaceRoots$)
  const filepath = useStateValue(viewmodel.filepath$)
  const observedLocationRef = React.useRef<string>(`${location.pathname}${location.search}`)
  const pendingUrlRef = React.useRef<string | null>(null)

  React.useLayoutEffect(() => {
    const currentUrl = `${location.pathname}${location.search}`
    if (!viewmodel.workspaceConfigLoaded && location.pathname.startsWith('/ws/')) return
    if (pendingUrlRef.current === currentUrl) {
      pendingUrlRef.current = null
      observedLocationRef.current = currentUrl
    } else if (observedLocationRef.current !== currentUrl) {
      pendingUrlRef.current = null
      observedLocationRef.current = currentUrl
      const legacyWorkspaceTag = location.pathname.startsWith('/ws/')
        ? decodePathSegment(location.pathname.slice('/ws/'.length))
        : undefined
      const route = resolveWorkspaceRoute(
        location.pathname,
        location.search,
        legacyWorkspaceTag,
        viewmodel.legacyWorkspaces,
      )
      const targetRoot = route.hasWorkspaceRoot
        ? route.workspaceRoot
        : (workspaceRoot ?? workspaceRoots[0] ?? null)
      const targetFilepath = route.hasFilepath ? route.filepath : null
      if (route.error !== viewmodel.workspaceError$.getSnapshot()) {
        viewmodel.workspaceError$.next(route.error)
      }
      if (targetRoot !== workspaceRoot) viewmodel.workspaceRoot$.next(targetRoot)
      if (targetFilepath !== filepath) viewmodel.filepath$.next(targetFilepath)
      if (targetRoot !== workspaceRoot || targetFilepath !== filepath) return
    }

    const nextUrl = createWorkspaceUrl(workspaceRoot, filepath)
    if (currentUrl !== nextUrl && pendingUrlRef.current !== nextUrl) {
      pendingUrlRef.current = nextUrl
      void navigate(nextUrl, { replace: true })
    }
  }, [
    filepath,
    location.pathname,
    location.search,
    navigate,
    viewmodel,
    workspaceRoot,
    workspaceRoots,
  ])
}

export const createWorkspaceUrl = (root: string | null, filepath?: string | null): string => {
  const params = new URLSearchParams()
  if (root) params.set('root', root)
  if (filepath) params.set('filepath', filepath)
  const search = params.toString()
  return search ? `/ws?${search}` : '/ws'
}

const createFileUrl = (filepath: string): string => {
  const params = new URLSearchParams({ filepath })
  return `/file?${params}`
}

const normalizeWorkspaceRoots = (roots: readonly string[]): string[] => {
  return Array.from(
    new Set(
      roots
        .map(normalizeAbsoluteFilepath)
        .filter((root): root is string => typeof root === 'string'),
    ),
  )
}

const findLegacyWorkspaceRoot = (
  tag: string | null,
  legacyWorkspaces: readonly ILegacyWorkspace[],
): string | null => {
  if (!tag) return null
  const item = legacyWorkspaces.find(item => item.tag.toLowerCase() === tag.toLowerCase())
  return item ? normalizeAbsoluteFilepath(item.path) : null
}

const resolveWorkspaceRoute = (
  pathname: string,
  search: string,
  legacyWorkspaceTag: string | undefined,
  legacyWorkspaces: readonly ILegacyWorkspace[],
): {
  workspaceRoot: string | null
  filepath: string | null
  hasWorkspaceRoot: boolean
  hasFilepath: boolean
  error: string | null
} => {
  const params = new URLSearchParams(search)
  const rawFilepath = params.get('filepath')
  if (legacyWorkspaceTag && pathname !== '/ws') {
    const workspaceRoot = findLegacyWorkspaceRoot(legacyWorkspaceTag, legacyWorkspaces)
    return {
      workspaceRoot,
      filepath:
        workspaceRoot && rawFilepath
          ? resolveLegacyWorkspaceFilepath(workspaceRoot, rawFilepath)
          : null,
      hasWorkspaceRoot: true,
      hasFilepath: rawFilepath !== null,
      error: workspaceRoot ? null : `Unknown legacy workspace: ${legacyWorkspaceTag}`,
    }
  }

  return {
    workspaceRoot: normalizeAbsoluteFilepath(params.get('root') || ''),
    filepath: readAbsoluteSearchParam(rawFilepath),
    hasWorkspaceRoot: params.has('root'),
    hasFilepath: rawFilepath !== null,
    error:
      params.has('root') && !normalizeAbsoluteFilepath(params.get('root') || '')
        ? 'Workspace root must be an absolute path.'
        : rawFilepath !== null && !readAbsoluteSearchParam(rawFilepath)
          ? 'File path must be an absolute path.'
          : null,
  }
}

const resolveLegacyWorkspaceFilepath = (root: string, filepath: string): string => {
  let decodedFilepath: string
  try {
    decodedFilepath = decodeURIComponent(filepath)
  } catch {
    decodedFilepath = filepath
  }
  return resolveWorkspaceFilepath(root, decodedFilepath.replace(/^[/\\]+/, ''))
}

const decodePathSegment = (value: string): string => {
  try {
    return decodeURIComponent(value)
  } catch {
    return value
  }
}
