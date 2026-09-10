import React from 'react'
import { ApiRoutePathEnum } from '@/shared/constant/api'
import { PdfView } from '@/view/filetype/pdf/View'

interface IProps {
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly storageKeyScope: string
}

export const PdfAdaptor: React.FC<IProps> = ({ filepath, storageKeyScope }) => {
  const url = React.useMemo(() => {
    const params = new URLSearchParams({ filepath })
    return `${ApiRoutePathEnum.FILE_RAW}?${params}`
  }, [filepath])
  return <PdfView url={url} storageKeyScope={storageKeyScope} />
}
