import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue, useViewModel } from '@guanghechen/react-viewmodel'
import React from 'react'
import { relativeWorkspaceFilepath, resolveWorkspaceFilepath } from '@/common/util/path'
import type { FileTreeModeEnum, IFileTreeContext, IFileTreeFileNode } from '@/container/filetree'
import {
  FileTreeComposer,
  FileTreeContextType,
  FileTreeMode,
  FileTreeSearch,
  FileTreeViewModel,
} from '@/container/filetree'
import { useGetWorkspaceFiles } from '@/hook/api/workspace/files'
import { useWorkspaceViewmodel } from '../context'

export const FileTree: React.FC = () => {
  const workspaceVM = useWorkspaceViewmodel()
  const mode: FileTreeModeEnum = useStateValue(workspaceVM.filetreeMode$)
  const workspaceRoot: string | null = useStateValue(workspaceVM.workspaceRoot$)

  const onFileNodeClick = useEventCallback((node: IFileTreeFileNode): void => {
    if (workspaceRoot) {
      workspaceVM.filepath$.next(
        resolveWorkspaceFilepath(workspaceRoot, node.filepath || node.uuid),
      )
    }
  })

  const viewmodel: FileTreeViewModel | null = useViewModel<FileTreeViewModel>(() => {
    return new FileTreeViewModel({
      currentFilepath: null,
    })
  })
  const context: IFileTreeContext | null = React.useMemo<IFileTreeContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <FileTreeContextType.Provider value={context}>
        <div className="flex h-full flex-col">
          <div className="flex-initial">
            <FileTreeSearch viewmodel={viewmodel} />
          </div>
          <div className="my-2 mr-4 flex flex-initial justify-end">
            <FileTreeMode
              viewmodel={viewmodel}
              mode={mode}
              onModeChange={mode => workspaceVM.filetreeMode$.next(mode)}
            />
          </div>
          <div className="w-full h-full flex-auto overflow-auto pr-2">
            <FileTreeComposer viewmodel={viewmodel} mode={mode} onFileNodeClick={onFileNodeClick} />
          </div>
        </div>
      </FileTreeContextType.Provider>
      <SideEffect viewmodel={viewmodel} />
    </React.Fragment>
  )
}

const SideEffect: React.FC<{ viewmodel: FileTreeViewModel }> = props => {
  const { viewmodel } = props
  const workspaceVM = useWorkspaceViewmodel()
  const sidebarVisible: boolean = useStateValue<boolean>(workspaceVM.sidebarVisible$)
  const revealTick: number = useStateValue<number>(workspaceVM.revealTick$)
  const filetreeDirtyTick: number = useStateValue<number>(workspaceVM.filetreeDirtyTick$)
  const workspaceError: string | null = useStateValue(workspaceVM.workspaceError$)

  const filepath: string | null = useStateValue(workspaceVM.filepath$)
  const workspaceRoot: string | null = useStateValue(workspaceVM.workspaceRoot$)
  const {
    root: canonicalRoot,
    files,
    error,
  } = useGetWorkspaceFiles(workspaceRoot, filetreeDirtyTick)
  const displayRoot = canonicalRoot ?? workspaceRoot
  const displayFilepath =
    filepath && displayRoot ? relativeWorkspaceFilepath(filepath, displayRoot) : filepath

  React.useEffect(() => {
    viewmodel.currentFilepath$.next(displayFilepath)
  }, [displayFilepath, viewmodel.currentFilepath$])

  React.useEffect(() => {
    viewmodel.updateFromFilepaths(
      displayRoot ? files.map(filepath => relativeWorkspaceFilepath(filepath, displayRoot)) : [],
    )
  }, [displayRoot, files, viewmodel])

  React.useEffect(() => {
    if (workspaceRoot && canonicalRoot && workspaceRoot !== canonicalRoot) {
      workspaceVM.replaceWorkspaceRoot(workspaceRoot, canonicalRoot)
    }
  }, [canonicalRoot, workspaceRoot, workspaceVM])

  React.useEffect(() => {
    if (!sidebarVisible) return

    const { selector } = viewmodel.reveal(displayFilepath)
    if (!selector) return

    let cancelled: boolean = false
    setTimeout(() => {
      if (cancelled) return

      const element: HTMLElement | null = document.querySelector(selector)
      element?.scrollIntoView({
        behavior: 'smooth',
        block: 'center',
      })
    }, 200)

    return (): void => {
      cancelled = true
    }
  }, [revealTick, sidebarVisible, displayFilepath, viewmodel])

  const displayedError = workspaceError ?? error
  return displayedError ? (
    <div className="absolute bottom-3 left-3 right-3 rounded-md bg-red-50 px-3 py-2 text-xs text-red-700 shadow-sm dark:bg-red-950/80 dark:text-red-300">
      {displayedError}
    </div>
  ) : (
    <React.Fragment />
  )
}
SideEffect.displayName = 'FileTreeSideEffect'
