import React from 'react'
import { JsonlViewContextType } from './context'
import { JsonlViewViewModel } from './viewmodel'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly children: React.ReactNode
}

export const JsonlViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, children } = props
  const [viewmodel] = React.useState(
    () =>
      new JsonlViewViewModel({
        workspace,
        filepath,
      }),
  )

  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return <JsonlViewContextType.Provider value={value}>{children}</JsonlViewContextType.Provider>
}

// Export ModeEnum as JsonlModeEnum for backwards compatibility
export { ModeEnum as JsonlModeEnum } from './types'
