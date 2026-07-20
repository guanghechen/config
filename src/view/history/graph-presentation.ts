import type { IGitReference } from '../../git/commit'
import type { ICommitGraphRow } from '../../history/commit-graph'

const MAX_VISIBLE_LANES = 4
const GRAPH_LANE_COLORS = [
  'charts.blue',
  'charts.purple',
  'charts.orange',
  'charts.green',
  'charts.red',
] as const

export function formatCommitGraphPrefix(row: ICommitGraphRow): string {
  if (row.laneCount === 1 && row.parentCount < 2) return ''

  const visibleLaneCount = Math.min(row.laneCount, MAX_VISIBLE_LANES)
  const cells: string[] = Array.from({ length: visibleLaneCount }, (_, lane) =>
    lane === row.lane ? '●' : '│',
  )
  if (row.lane >= MAX_VISIBLE_LANES) cells.push('…', '●')
  const merge = row.parentCount > 1 ? '─┬' : ''
  return `${cells.join(' ')}${merge}`
}

export function formatCommitReferenceSummary(references: ReadonlyArray<IGitReference>): string {
  const labels = references.map(formatReference)
  if (labels.length <= 2) return labels.join(' · ')
  return `${labels.slice(0, 2).join(' · ')} · +${labels.length - 2}`
}

export function formatCommitReferenceTooltip(
  references: ReadonlyArray<IGitReference>,
): string | null {
  if (references.length === 0) return null
  return references.map(formatReference).join('\n')
}

export function resolveCommitGraphColorId(lane: number): string {
  return GRAPH_LANE_COLORS[lane % GRAPH_LANE_COLORS.length] ?? GRAPH_LANE_COLORS[0]
}

function formatReference(reference: IGitReference): string {
  switch (reference.kind) {
    case 'head':
      return reference.name === 'HEAD' ? 'HEAD' : `HEAD → ${reference.name}`
    case 'localBranch':
      return reference.name
    case 'remoteBranch':
      return `☁ ${reference.name}`
    case 'tag':
      return `tag: ${reference.name}`
    case 'other':
      return reference.name
  }
}
