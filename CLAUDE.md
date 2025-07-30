# CLAUDE.md

This is Yozora, a Neovim markdown preview application built with TypeScript, React, and Vite. It
provides real-time markdown preview with advanced features like syntax highlighting, math rendering,
file tree navigation, and support for various file formats (markdown, JSON, PDF, SVG, images).

## Requirements

- **MUST**: Use `I`-prefixed naming convention for types and interfaces.names for interfaces/types
  (`IChatMessage`, `IUser`)
- **MUST**: Run `yarn format` is enough to check if the code is formatted correctly.

## Architecture

### Frontend Structure

- **Entry point**: `src/main.tsx` - React app with routing and context providers
- **Main views**: `src/view/workspace/` - Primary workspace interface with sidebar and main content
  area
- **Components**:
  - `src/component/markdown/` - Markdown rendering using Yozora parser with custom AST handling
  - `src/component/filetree/` - File tree navigation with context and viewmodel pattern
  - `src/component/code-highlighter/` - Syntax highlighting using PrismJS
  - `src/component/json/` - JSON viewer with collapsible fields

### Backend/Server Structure

- **Server plugins**: `server/plugin/` - Vite plugins for API and WebSocket handling
- **API endpoints**: `server/plugin/api/handle/` - File operations and workspace management
- **WebSocket**: `server/plugin/ws.ts` - Real-time file change notifications
- **Markdown parser**: `server/util/parseMarkdown.ts` - Server-side markdown processing using Yozora

### Key Patterns

- **Context + ViewModel**: Components use React context with viewmodel pattern for state management
- **AST-based rendering**: Markdown rendering works with Yozora AST nodes rather than raw text
- **File watching**: Server monitors file changes and notifies clients via WebSocket
- **Multi-format support**: Handles markdown, JSON, PDF, images, and SVG files

### Configuration

- **Environment**: `env.ts` - Server configuration with dotenv support
- **TypeScript**: Multiple tsconfig files for different build targets
- **Vite**: Custom plugins for API and WebSocket integration
- **Aliases**: `@/` maps to `src/`, `@/shared` maps to `shared/`

### Important Dependencies

- **@yozora/parser**: Core markdown parsing library
- **@yozora/react-mathjax**: Math rendering
- **@excalidraw/excalidraw**: Drawing/diagram support
- **prismjs**: Syntax highlighting
- **react-pdf**: PDF viewing
- **chokidar**: File watching
