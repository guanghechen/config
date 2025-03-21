import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { IFileTreeContext, IFileTreeFileNode } from '@/component/filetree'
import {
  FileTree as FileTreeComponent,
  FileTreeContextType,
  FileTreeSearch,
  FileTreeViewModel,
} from '@/component/filetree'
import { useWorkspaceFiles } from '@/hook/useWorkspaceFiles'
import { useWorkspaceViewmodel } from '../context'

export const FileTree: React.FC = () => {
  const workspaceVM = useWorkspaceViewmodel()
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
        <FileTreeSearch viewmodel={viewmodel} />
        <FileTreeComponent viewmodel={viewmodel} onFileNodeClick={onFileNodeClick} />
      </FileTreeContextType.Provider>
    </React.Fragment>
  )
}

const SideEffect: React.FC<{ viewmodel: FileTreeViewModel }> = props => {
  const { viewmodel } = props
  const workspaceVM = useWorkspaceViewmodel()

  const filepath: string | null = useStateValue(workspaceVM.filepath$)
  const workspace: string | null = useStateValue(workspaceVM.workspace$)
  const { files } = useWorkspaceFiles(workspace, 0)

  React.useEffect(() => {
    viewmodel.currentFilepath$.next(filepath)
  }, [filepath, viewmodel.currentFilepath$])

  React.useEffect(() => {
    viewmodel.updateFromFilepaths(files)
  }, [files, viewmodel])

  return <React.Fragment />
}
SideEffect.displayName = 'FileTreeSideEffect'
