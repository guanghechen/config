import type { Plugin } from 'vite'

const plugin = (): Plugin => {
  return {
    name: '@guanghechen/ws',
    configureServer(server) {
      setTimeout(() => {
        server.ws.send('guanghechen', { data: 'Hello from customized plugin!' })
      }, 3000)
    },
  }
}

export default plugin
