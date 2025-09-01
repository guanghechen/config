import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { LoginModal } from '@/component/LoginModal'
import { Settings } from '@/container/Settings'
import { useAuthViewModel } from '@/context/auth'
import { setAuthenticationRequiredHandler } from '@/shared/api/requester'

interface GlobalLayoutProps {
  children: React.ReactNode
}

export const GlobalLayout: React.FC<GlobalLayoutProps> = ({ children }) => {
  const authViewModel = useAuthViewModel()
  const signed = useStateValue(authViewModel.signed$)

  React.useEffect(() => {
    // Set up global authentication handler to use the viewmodel
    setAuthenticationRequiredHandler(() => {
      authViewModel.requestAuthentication()
    })
  }, [authViewModel])

  const handleCloseLoginModal = React.useCallback(() => {
    authViewModel.closeAuthenticationDialog()
  }, [authViewModel])

  return (
    <React.Fragment>
      {children}
      <Settings />
      <LoginModal isOpen={signed} onClose={handleCloseLoginModal} />
    </React.Fragment>
  )
}

GlobalLayout.displayName = 'GlobalLayout'
