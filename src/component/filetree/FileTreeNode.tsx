import React from 'react'
import {
  ChevronDownIcon,
  ChevronRightIcon,
  FileTypeIcon,
  FolderIcon,
  FolderOpenIcon,
} from '@/component/icon/filetype'
import type { IFileTreeNode } from './context'

interface IProps {
  readonly node: IFileTreeNode
  readonly collapsed?: boolean | undefined
}

export class FileTreeNode extends React.Component<IProps> {
  public static readonly displayName = 'FileTreeNode'

  public override render(): React.ReactElement {
    const { node } = this.props

    if (node.type === 'folder') {
      const { collapsed = node.collapsed } = this.props
      return (
        <div className="flex cursor-pointer items-center" data-filetree-node-uuid={node.uuid}>
          <span className="mr-1 flex-shrink-0">
            {collapsed ? <ChevronRightIcon /> : <ChevronDownIcon />}
          </span>
          <span className="mr-1 flex-shrink-0">
            {collapsed ? (
              <FolderIcon className="text-blue-500" />
            ) : (
              <FolderOpenIcon className="text-blue-500" />
            )}
          </span>
          <span className="truncate">{node.basename}</span>
        </div>
      )
    }

    return (
      <div className="flex cursor-pointer items-center" data-filetree-node-uuid={node.uuid}>
        <span className="invisible mr-1 flex-shrink-0">
          <ChevronRightIcon />
        </span>
        <span className="mr-1 flex-shrink-0">
          <FileTypeIcon extname={node.extname} />
        </span>
        <span className="truncate">{node.basename}</span>
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps): boolean {
    const props = this.props
    return props.node !== nextProps.node || props.collapsed !== nextProps.collapsed
  }
}
