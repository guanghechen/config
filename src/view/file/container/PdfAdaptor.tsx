import React from 'react'
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
    return `/api/file/raw?${params}`
  }, [workspace, filepath])
  return <PdfView url={url} storageKeyScope={storageKeyScope} />
}
