import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useNavigate } from 'react-router-dom'
import { MarkdownTopProvider } from '@/container/markdown'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { Composer } from './Composer'
import { WorkspaceViewProvider, useWorkspaceViewmodel } from './context'
import { resolveWorkspaceLink } from './util/link'

export const WorkspaceView: React.FC = () => {
  const siteVM = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(siteVM.theme$)

  return (
    <WorkspaceViewProvider>
      <WorkspaceContent theme={theme} />
    </WorkspaceViewProvider>
  )
}

WorkspaceView.displayName = 'WorkspaceView'

const WorkspaceContent: React.FC<{ readonly theme: SiteTheme }> = ({ theme }) => {
  const viewmodel = useWorkspaceViewmodel()
  const workspaceRoot = useStateValue(viewmodel.workspaceRoot$)
  const navigate = useNavigate()
  const resolveLinkUrl = React.useCallback(
    (url: string): string => resolveWorkspaceLink(url, workspaceRoot),
    [workspaceRoot],
  )
  const onLinkClick = React.useCallback<React.MouseEventHandler<HTMLAnchorElement>>(
    event => {
      if (
        event.defaultPrevented ||
        event.button !== 0 ||
        event.metaKey ||
        event.ctrlKey ||
        event.shiftKey ||
        event.altKey
      ) {
        return
      }

      const anchor = event.currentTarget
      const target = anchor.getAttribute('target')
      if (anchor.hasAttribute('download') || (target && target !== '_self')) return

      const href = anchor.getAttribute('href')
      if (!href?.startsWith('/ws?') || !workspaceRoot) return
      const url = new URL(href, window.location.href)
      if (
        url.origin !== window.location.origin ||
        url.pathname !== '/ws' ||
        url.searchParams.get('root') !== workspaceRoot
      ) {
        return
      }

      event.preventDefault()
      void navigate(`${url.pathname}${url.search}${url.hash}`)
    },
    [navigate, workspaceRoot],
  )

  return (
    <MarkdownTopProvider theme={theme} resolveLinkUrl={resolveLinkUrl} onLinkClick={onLinkClick}>
      <Composer />
    </MarkdownTopProvider>
  )
}

WorkspaceContent.displayName = 'WorkspaceViewContent'
