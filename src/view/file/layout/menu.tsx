import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { FilePath } from '@/common/component/FilePath'
import { useFileViewmodel } from '../context'

export const Menu: React.FC = () => {
  const viewmodel = useFileViewmodel()
  const filepath = useStateValue(viewmodel.filepath$)
  const history = useStateValue(viewmodel.filepathHistory$)

  const handleHistorySelect = React.useCallback(
    (selectedFilepath: string) => {
      viewmodel.filepath$.next(selectedFilepath)
    },
    [viewmodel],
  )

  return (
    <React.Fragment>
      {filepath && (
        <FilePath
          filepath={filepath}
          workspace={null}
          history={history}
          onHistorySelect={handleHistorySelect}
        />
      )}
    </React.Fragment>
  )
}

Menu.displayName = 'FileViewMenu'
