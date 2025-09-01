import React from 'react'
import { usePersistAsync } from '@/hook/usePersistAsync'
import { useViewModel } from '@/hook/useViewModel'
import { universalStorage } from '@/util/storage'
import type { IAuthContext } from './context'
import { AuthContextType } from './context'
import type { IAuthData } from './viewmodel'
import { AuthViewModel } from './viewmodel'

const storageKey: string = '#/context/auth'

interface ISideEffectProps {
  readonly viewmodel: AuthViewModel
}

export const AuthContextProvider: React.FC<{ children: React.ReactNode }> = props => {
  const viewmodel: AuthViewModel | null = useViewModel<AuthViewModel>(async () => {
    // Try to get context data from new storage system
    const contextData = await universalStorage.getContext<Partial<IAuthData>>(storageKey)

    // Also check for auth token in dedicated auth storage
    const authToken = await universalStorage.getAuthToken()

    const initialData: Partial<IAuthData> = {
      ...contextData,
      ...(authToken && { token: authToken }),
    }

    const token = authToken || initialData.token
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

  usePersistAsync(viewmodel, storageKey, [viewmodel.token$, viewmodel.isAuthenticated$])

  return <React.Fragment />
}
SideEffect.displayName = 'AuthContextSideEffect'
