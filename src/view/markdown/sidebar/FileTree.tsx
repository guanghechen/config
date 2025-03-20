import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { IFileTreeNode } from '@/component/filetree'
import { FileTreeNode, useFileTreeViewmodel } from '@/component/filetree'
import { useSiteViewmodel } from '@/context/site'
import { useWorkspaceFiles } from '@/hook/useWorkspaceFiles'

export const FileTree: React.FC = () => {
  const siteViewmodel = useSiteViewmodel()
  const filetreeViewmodel = useFileTreeViewmodel()

  const workspace: string | null = useStateValue(siteViewmodel.workspace$)
  const root = useStateValue(filetreeViewmodel.root$)
  const dataMap = useStateValue(filetreeViewmodel.dataMap$)

  const { files } = useWorkspaceFiles(workspace, 0)

  React.useEffect(() => {
    filetreeViewmodel.updateFromFilepaths(files)
  }, [files])

  const onNodeClick = useEventCallback((node: IFileTreeNode) => {
    if (node.type === 'file') {
      const data = filetreeViewmodel.dataMap$.getSnapshot().get(node.uuid)!
      siteViewmodel.filepath$.next(data.filepath || node.uuid)
    }
  })

  if (!root) {
    return <div className="p-4">Loading file tree...</div>
  }

  return (
    <div className="h-full overflow-auto text-sm">
      {root.children.map(node => {
        const nodeData = dataMap.get(node.uuid)!
        return (
          <FileTreeNode key={node.uuid} node={node} data={nodeData} onNodeClick={onNodeClick} />
        )
      })}
    </div>
  )
}
