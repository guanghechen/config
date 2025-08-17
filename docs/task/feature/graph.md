@src/view/filetype/text/

Since we have a transformedNodes which have uuid and parents uuid, that means we can structure a DAG, so I want to provider the third option 'Graph' view on the ViewModelDropdown' and then render a graph with canvas based on the transformedNodes on the 'view' pane.

## Task Details

1. I wish the graph view is based on a Canvas, and the nodes rendered as Node on the Canvas construct a DAG. the canvas could be zoom/scale/drag, and each node should be drag'n'drop able, and when click it can view detail content.

2. We should implement a pure component of the DAG Graph placed onto the @src/component/graph/dag/

3. We should support customized Node Renderer based by the node data.

4. The Node should be layout reasonable, I'm not very family with the layout algorithm, you can implement one or pick a matured method from the open source.

5. The Edge should be customizable since sometimes we want the edge can have animation or dashed style and etc.

6. After implement such a DAG graph component, let's using it into the src/view/filetype/text/ on the 'graph' viewMode on the view pane.
