import React from 'react'
import { ApiRoutePathEnum } from '@/shared/constant/api'
import { PdfView } from '@/view/filetype/pdf/View'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly storageKeyScope: string
}

export const PdfAdaptor: React.FC<IProps> = ({ workspace, filepath, storageKeyScope }) => {
  const url = React.useMemo(() => {
    const params = new URLSearchParams({ filepath })
    if (workspace) params.set('workspace', workspace)
    return `${ApiRoutePathEnum.FILE_RAW}?${params}`
  }, [workspace, filepath])
  return <PdfView url={url} storageKeyScope={storageKeyScope} />
}
