import React from 'react'
import { ReactMarkdown } from '@/container/markdown/ReactMarkdown'
import { useMarkdownTopViewmodel } from '@/container/markdown/context/top'
import type { IMarkdownSource, INode } from '@/shared/whiteboard/model'
import type { IMarkdownResources } from './resources'
import { SketchBorder } from './SketchBorder'
import { resolveStyle } from '@/shared/whiteboard/colors'
import type { IWhiteboardTheme } from './theme'
import { normalizeAngle } from '@/shared/whiteboard/pose'

const ReferencedMarkdown: React.FC<{ filepath: string; resources: IMarkdownResources }> = ({
  filepath,
  resources,
}) => {
  const subscribe = React.useCallback(
    (listener: () => void) => resources.subscribe(filepath, listener),
    [resources, filepath],
  )
  const getSnapshot = React.useCallback(() => resources.get(filepath), [resources, filepath])
  const resource = React.useSyncExternalStore(subscribe, getSnapshot)
  return (
    <>
      {resource.error && (
        <p className="wb-resource-error" role="alert">
          {resource.error}
        </p>
      )}
      {resource.data?.markdown ? (
        <ReactMarkdown ast={resource.data.markdown.ast} dontShowFirstHeading={false} />
      ) : (
        !resource.error && <p className="wb-placeholder">Loading Markdown…</p>
      )}
    </>
  )
}

const InlineMarkdown: React.FC<{ content: string }> = ({ content }) => {
  const top = useMarkdownTopViewmodel()
  const ast = React.useMemo(() => top.parseMarkdown(content), [top, content])
  return <ReactMarkdown ast={ast} dontShowFirstHeading={false} />
}

const MarkdownBody = React.memo<{ source: IMarkdownSource; resources: IMarkdownResources }>(
  ({ source, resources }) =>
    source.kind === 'file' ? (
      <ReferencedMarkdown filepath={source.filepath} resources={resources} />
    ) : (
      <InlineMarkdown content={source.content} />
    ),
)
MarkdownBody.displayName = 'WhiteboardMarkdownBody'

function imageUrl(url: string): string {
  return url.startsWith('/') && !url.startsWith('//') && !url.startsWith('/api/')
    ? `/api/file/raw?${new URLSearchParams({ filepath: url })}`
    : url
}

export const MarkdownCard = React.memo<{
  node: INode
  resources: IMarkdownResources
  theme: IWhiteboardTheme
}>(({ node, resources, theme }) => {
  const style = React.useMemo(() => resolveStyle(node.style, theme.colors), [node.style, theme])
  return (
    <article
      data-node-id={node.id}
      className={`wb-card${node.type === 'image' ? ' wb-image' : ''}`}
      style={{
        left: node.x,
        top: node.y,
        width: node.width,
        height: node.height,
        transform:
          normalizeAngle(node.rotation ?? 0) || node.flipX || node.flipY
            ? `rotate(${normalizeAngle(node.rotation ?? 0)}deg) scale(${node.flipX ? -1 : 1},${node.flipY ? -1 : 1})`
            : undefined,
        transformOrigin: '50% 50%',
        background: node.type === 'image' ? 'transparent' : theme.paper,
        borderColor: node.style.roughness ? 'transparent' : style.stroke,
        borderWidth: node.type === 'image' ? 0 : node.style.strokeWidth,
      }}
    >
      {(node.style.roughness > 0 || node.type === 'image') && (
        <SketchBorder
          id={node.id}
          width={node.width}
          height={node.height}
          style={style}
          borderWidth={node.type === 'image' ? 0 : undefined}
        />
      )}
      <div className="wb-card-surface">
        {node.type !== 'image' && (
          <div className="wb-card-label">
            {node.type === 'markdown' && node.source.kind === 'file'
              ? node.source.filepath
              : 'Markdown'}
          </div>
        )}
        <div className="wb-card-content" data-card-content>
          {node.type === 'markdown' && <MarkdownBody source={node.source} resources={resources} />}
          {node.type === 'image' && (
            <img
              src={imageUrl(node.url)}
              alt="Whiteboard image"
              draggable={false}
              onError={event => {
                const image = event.currentTarget
                image.alt = 'Unable to load image'
              }}
            />
          )}
        </div>
      </div>
    </article>
  )
})
MarkdownCard.displayName = 'WhiteboardMarkdownCard'
