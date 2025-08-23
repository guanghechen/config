import React from 'react'
import { ImageView } from '@/view/filetype/image/View'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
}

export const ImageAdaptor: React.FC<IProps> = ({ workspace, filepath }) => {
  const url = React.useMemo(() => {
    const params = new URLSearchParams({ filepath })
    if (workspace) {
      params.set('workspace', workspace)
    }
    return `/api/file/raw?${params}`
  }, [workspace, filepath])

  return <ImageView url={url} />
}
