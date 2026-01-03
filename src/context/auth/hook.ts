import React from 'react'
import { AuthContextType } from './context'
import type { AuthViewModel } from './viewmodel'

export const useAuthViewModel = (): AuthViewModel => {
  return React.useContext(AuthContextType).viewmodel
}
