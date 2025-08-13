import type { ViewModel } from '@guanghechen/react-viewmodel'
import React from 'react'

export const useViewModelCleanup = (viewmodel: ViewModel): void => {
  React.useEffect(() => {
    return () => {
      setTimeout(() => viewmodel.dispose(), 10000)
    }
  }, [viewmodel])
}
