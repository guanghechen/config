import React from 'react'
import { useViewModel } from '@/hook/useViewModel'
import type { IAuthContext } from './context'
import { AuthContextType } from './context'
import { AuthViewModel } from './viewmodel'

interface ISideEffectProps {
  readonly viewmodel: AuthViewModel
}

export const AuthContextProvider: React.FC<{ children: React.ReactNode }> = props => {
  const viewmodel: AuthViewModel | null = useViewModel<AuthViewModel>(async () => {
    // No need to get stored data - authentication is checked via cookies
    return new AuthViewModel()
  })

  const context: IAuthContext | null = React.useMemo<IAuthContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <AuthContextType.Provider value={context}>{props.children}</AuthContextType.Provider>
      <SideEffect viewmodel={viewmodel} />
    </React.Fragment>
  )
}
AuthContextProvider.displayName = 'AuthContextProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel } = props

  // Check authentication status on mount
  React.useEffect(() => {
    void viewmodel.checkAuthenticationStatus()
  }, [viewmodel])

  return <React.Fragment />
}
SideEffect.displayName = 'AuthContextSideEffect'
