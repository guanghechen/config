import { useViewModel } from '@guanghechen/react-viewmodel'
import React from 'react'
import { usePersist } from '@/hook/usePersist'
import type { IAuthContext } from './context'
import { AuthContextType } from './context'
import type { IAuthData } from './viewmodel'
import { AuthViewModel } from './viewmodel'

const storageKey: string = '#/context/auth'

interface ISideEffectProps {
  readonly viewmodel: AuthViewModel
}

export const AuthContextProvider: React.FC<{ children: React.ReactNode }> = props => {
  const viewmodel: AuthViewModel | null = useViewModel<AuthViewModel>(() => {
    const initialData: Partial<IAuthData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const token = localStorage.getItem('auth_token') || initialData.token
    return AuthViewModel.fromData({ token, isAuthenticated: !!token })
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

  usePersist(viewmodel, storageKey, [viewmodel.token$, viewmodel.isAuthenticated$])

  return <React.Fragment />
}
SideEffect.displayName = 'AuthContextSideEffect'
