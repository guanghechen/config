import {
  Background,
  BackgroundVariant,
  Controls,
  MiniMap,
  type Node,
  type NodeMouseHandler,
  type NodeTypes,
  ReactFlow,
  useEdgesState,
  useNodesState,
} from '@xyflow/react'
import React from 'react'
import '@xyflow/react/dist/style.css'
import type { ITextTransformedNode } from '@/shared/types'
import { CustomNode } from './component/CustomNode'
import { NodeDetailsPanel } from './component/NodeDetailsPanel'
import { ReactFlowToolbar } from './component/ReactFlowToolbar'
import { type IReactFlowNodeData, transformNodesToReactFlow } from './util/adaptor'
import { getLayoutedElements } from './util/layout'

interface IProps {
  readonly data: ITextTransformedNode[]
  readonly theme?: 'light' | 'dark'
}

const nodeTypes: NodeTypes = {
  custom: CustomNode,
}

export const ReactFlowGraph: React.FC<IProps> = props => {
  const { data, theme = 'light' } = props

  const [selectedNode, setSelectedNode] = React.useState<Node | null>(null)
  const initialData = React.useMemo(() => {
    const { nodes, edges } = transformNodesToReactFlow(data)

    // Apply theme styling to edges
    const themedEdges = edges.map(edge => ({
      ...edge,
      style: {
        stroke: theme === 'dark' ? '#6b7280' : '#d1d5db',
        strokeWidth: 2,
      },
    }))

    return getLayoutedElements(nodes, themedEdges)
  }, [data, theme])

  const [nodes, setNodes, onNodesChange] = useNodesState(initialData.nodes as Node[])
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialData.edges)

  // Update nodes with theme
  const themedNodes = React.useMemo(() => {
    return nodes.map(node => ({
      ...node,
      data: {
        ...node.data,
        theme,
      },
    }))
  }, [nodes, theme])

  const handleNodeClick = React.useCallback<NodeMouseHandler>((_event, node) => {
    setSelectedNode(node)
  }, [])

  const handlePaneClick = React.useCallback(() => {
    setSelectedNode(null)
  }, [])

  const handleReLayout = React.useCallback(() => {
    const { nodes: layoutedNodes, edges: layoutedEdges } = getLayoutedElements(
      nodes as Array<Node<IReactFlowNodeData>>,
      edges,
    )
    setNodes(layoutedNodes as Node[])
    setEdges(layoutedEdges)
  }, [nodes, edges, setNodes, setEdges])

  const handleCloseDetails = React.useCallback(() => {
    setSelectedNode(null)
  }, [])

  // Update nodes and edges when data prop changes
  React.useEffect(() => {
    const { nodes: newNodes, edges: newEdges } = transformNodesToReactFlow(data)

    // Apply theme styling to edges
    const themedEdges = newEdges.map(edge => ({
      ...edge,
      style: {
        stroke: theme === 'dark' ? '#6b7280' : '#d1d5db',
        strokeWidth: 2,
      },
    }))

    const layoutedData = getLayoutedElements(newNodes, themedEdges)
    setNodes(layoutedData.nodes as Node[])
    setEdges(layoutedData.edges)
  }, [data, theme, setNodes, setEdges])

  return (
    <div className="relative w-full h-full flex">
      <div className="flex-1 relative">
        <ReactFlow
          nodes={themedNodes}
          edges={edges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onNodeClick={handleNodeClick}
          onPaneClick={handlePaneClick}
          nodeTypes={nodeTypes}
          fitView={true}
          proOptions={{ hideAttribution: true }}
          className={theme === 'dark' ? 'react-flow dark' : 'react-flow'}
          style={{ width: '100%', height: '100%' }}
        >
          <Controls />
          <MiniMap
            nodeColor={theme === 'dark' ? '#374151' : '#f9fafb'}
            nodeStrokeColor={theme === 'dark' ? '#6b7280' : '#d1d5db'}
            className={theme === 'dark' ? 'bg-gray-800' : 'bg-gray-100'}
          />
          <Background
            variant={BackgroundVariant.Dots}
            gap={20}
            size={1}
            color={theme === 'dark' ? '#374151' : '#e5e7eb'}
          />
          <ReactFlowToolbar theme={theme} onReLayout={handleReLayout} />
        </ReactFlow>
      </div>

      {selectedNode && (
        <NodeDetailsPanel node={selectedNode} theme={theme} onClose={handleCloseDetails} />
      )}
    </div>
  )
}

ReactFlowGraph.displayName = 'ReactFlowGraph'
