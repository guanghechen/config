import React from 'react'
import { ApiRoutePathEnum } from '@/shared/constant/api'
import { ImageView } from '@/view/filetype/image/View'

interface IProps {
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly storageKeyScope: string
}

export const ImageAdaptor: React.FC<IProps> = ({ filepath, storageKeyScope }) => {
  const url = React.useMemo(() => {
    const params = new URLSearchParams({ filepath })
    return `${ApiRoutePathEnum.FILE_RAW}?${params}`
  }, [filepath])

  return <ImageView url={url} storageKeyScope={storageKeyScope} />
}
