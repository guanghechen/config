import React from 'react'
import type { AuthViewModel } from './viewmodel'

export interface IAuthContext {
  readonly viewmodel: AuthViewModel
}

export const AuthContextType = React.createContext<IAuthContext>(null as unknown as IAuthContext)
AuthContextType.displayName = 'AuthContextType'

export const useAuthViewModel = (): AuthViewModel => {
  return React.useContext(AuthContextType).viewmodel
}
