import React from 'react'
import './host/style.css'
import { useStateValue } from '@guanghechen/react-viewmodel'
import { useSearchParams } from 'react-router-dom'
import { MarkdownTopProvider } from '@/container/markdown/context/top/Provider'
import { LoginModal } from '@/container/LoginModal'
import { useSiteViewmodel } from '@/context/site'
import { useMermaidSyncThemeEffect } from '@/hook/useMermaidSyncThemeEffect'
import { Whiteboard } from './Whiteboard'
import { BoardAppearance } from './host/BoardAppearance'
import { WorkspaceFileDialog } from './host/WorkspaceFileDialog'
import { MarkdownCode } from './host/MarkdownCode'
import { Markdown } from './host/markdown'
import { drafts, files, imageUrl, openFile } from './host/files'
import { useWhiteboardTheme } from './host/theme'
import type { IWhiteboardHost, IWhiteboardProps } from './contracts'

const TextEditor = React.lazy(() =>
  import('./host/TextEditor').then(module => ({ default: module.TextEditor })),
)
const markdownRenderers = { code: MarkdownCode }
const host: IWhiteboardHost = {
  files,
  drafts,
  imageUrl,
  openFile,
  Markdown,
  TextEditor,
  FilePicker: WorkspaceFileDialog,
  appearance: <BoardAppearance />,
  workspaceHref: '/ws',
}

export const WhiteboardView: React.FC = () => {
  const [search] = useSearchParams()
  const filepath = search.get('filepath') ?? undefined
  return (
    <>
      <WhiteboardBoard key={filepath ?? 'scratch'} filepath={filepath} />
      <LoginModal />
    </>
  )
}

export const WhiteboardBoard: React.FC<
  Pick<IWhiteboardProps, 'filepath' | 'initialDocument'>
> = props => {
  useMermaidSyncThemeEffect()
  const site = useSiteViewmodel()
  const mode = useStateValue(site.theme$)
  const { theme, ready } = useWhiteboardTheme()
  return (
    <MarkdownTopProvider theme={mode} customizedRendererMap={markdownRenderers}>
      <div className="wb-host" style={{ height: '100%', visibility: ready ? 'visible' : 'hidden' }}>
        <Whiteboard {...props} host={host} theme={theme} />
      </div>
    </MarkdownTopProvider>
  )
}
