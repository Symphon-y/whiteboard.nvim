import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  publicDir: false,
  build: {
    outDir:                'public',
    emptyOutDir:           false,
    chunkSizeWarningLimit: 5000,
    rollupOptions: {
      input: 'src/main.jsx',
      output: {
        entryFileNames:       'app.js',
        format:               'iife',
        name:                 'WhiteboardApp',
        inlineDynamicImports: true,
      },
    },
  },
  optimizeDeps: {
    include: ['@excalidraw/excalidraw'],
  },
})
