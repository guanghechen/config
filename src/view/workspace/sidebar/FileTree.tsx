import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import type { FileTreeModeEnum, IFileTreeContext, IFileTreeFileNode } from '@/component/filetree'
import {
  FileTreeComposer,
  FileTreeContextType,
  FileTreeMode,
  FileTreeSearch,
  FileTreeViewModel,
} from '@/component/filetree'
import { PRESET_CLASSES } from '@/constant/classes'
import { useWorkspaceFiles } from '@/hook/useWorkspaceFiles'
import { useWorkspaceViewmodel } from '../context'

export const FileTree: React.FC = () => {
  const workspaceVM = useWorkspaceViewmodel()
  const mode: FileTreeModeEnum = useStateValue(workspaceVM.filetreeMode$)

  const [viewmodel] = React.useState<FileTreeViewModel>(() => {
    const viewmodel = new FileTreeViewModel({
      currentFilepath: workspaceVM.filepath$.getSnapshot(),
    })
    return viewmodel
  })

  const context: IFileTreeContext = React.useMemo<IFileTreeContext>(
    () => ({ viewmodel }),
    [viewmodel],
  )

  const onFileNodeClick = useEventCallback((node: IFileTreeFileNode): void => {
    workspaceVM.filepath$.next(node.filepath || node.uuid)
  })

  return (
    <React.Fragment>
      <SideEffect viewmodel={viewmodel} />
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
          <div
            className={cn('w-full h-full flex-auto overflow-auto pr-2', PRESET_CLASSES.scrollbar)}
          >
            <FileTreeComposer viewmodel={viewmodel} mode={mode} onFileNodeClick={onFileNodeClick} />
          </div>
        </div>
      </FileTreeContextType.Provider>
    </React.Fragment>
  )
}

const SideEffect: React.FC<{ viewmodel: FileTreeViewModel }> = props => {
  const { viewmodel } = props
  const workspaceVM = useWorkspaceViewmodel()
  const sidebarVisible = useStateValue(workspaceVM.sidebarVisible$)

  const filepath: string | null = useStateValue(workspaceVM.filepath$)
  const workspace: string | null = useStateValue(workspaceVM.workspace$)
  const { files } = useWorkspaceFiles(workspace, 0)

  React.useEffect(() => {
    viewmodel.currentFilepath$.next(filepath)
  }, [filepath, viewmodel.currentFilepath$])

  React.useEffect(() => {
    viewmodel.updateFromFilepaths(files)
  }, [files, viewmodel])

  React.useEffect(() => {
    if (!sidebarVisible) return

    const { selector } = viewmodel.reveal(filepath)
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
  }, [sidebarVisible, filepath, viewmodel])

  return <React.Fragment />
}
SideEffect.displayName = 'FileTreeSideEffect'
