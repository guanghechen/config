import type { ViewModel } from '@guanghechen/react-viewmodel'
import React from 'react'

interface IProps {
  readonly viewmodel: ViewModel
}

export const ViewModelCleanupSideEffect: React.FC<IProps> = props => {
  const { viewmodel } = props

  React.useEffect(() => {
    return () => {
      const name: string = viewmodel.constructor.name
      console.log(`[viewmodel#${name}] disposing`)
      viewmodel.dispose()
    }
  }, [viewmodel])

  return <React.Fragment />
}

ViewModelCleanupSideEffect.displayName = 'ViewModelCleanupSideEffect'
