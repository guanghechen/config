import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { ITextTransformConfig, ITextTransformedNode } from '@/shared/types'
import { NavListItem } from '../container/NavListItem'
import type { IChainPath } from '../context'
import { useTextViewViewModel } from '../context'
import { stringArrayToChainPaths } from '../utils'

export const NavPane: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const records: ITextTransformedNode[] = useStateValue(viewmodel.records$)
  const activeRecordIndex: number | null = useStateValue(viewmodel.activeRecordIndex$)
  const transformConfig: ITextTransformConfig = useStateValue(viewmodel.transformConfig$)
  const chainPaths: IChainPath[] = stringArrayToChainPaths(transformConfig.chainPaths)

  const containerRef = React.useRef<HTMLDivElement>(null)

  React.useEffect(() => {
    if (activeRecordIndex !== null && containerRef.current) {
      const activeItem = containerRef.current.querySelector(
        `[data-nav-index="${activeRecordIndex}"]`,
      )
      if (activeItem) {
        activeItem.scrollIntoView({ behavior: 'smooth', block: 'center' })
      }
    }
  }, [activeRecordIndex])

  return (
    <React.Fragment>
      <div className="box-border flex-initial sticky top-0 z-50 bg-white round rounded-lg dark:bg-gray-800 border-gray-200 dark:border-gray-700">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
          Navigation ({records.length})
        </h3>
      </div>
      <div className="flex-1" ref={containerRef}>
        {records.map((record, index) => (
          <NavListItem
            key={record.uuid}
            record={record}
            index={index}
            isActive={activeRecordIndex === index}
            chainPaths={chainPaths}
          />
        ))}
      </div>
    </React.Fragment>
  )
}

NavPane.displayName = 'TextViewNavPane'
