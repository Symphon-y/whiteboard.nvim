import React, { useEffect, useRef, useCallback } from 'react'
import { createRoot } from 'react-dom/client'
import { Excalidraw } from '@excalidraw/excalidraw'

function App() {
  const apiRef      = useRef(null)
  const wsRef       = useRef(null)
  const saveTimer   = useRef(null)
  const initialized = useRef(false)

  // Fetch persisted board on first mount
  useEffect(() => {
    fetch('/api/board')
      .then(r => r.json())
      .then(data => {
        if (!initialized.current && apiRef.current && data.elements?.length > 0) {
          initialized.current = true
          apiRef.current.updateScene({
            elements: data.elements,
            appState: data.appState || {},
          })
        }
      })
      .catch(console.error)
  }, [])

  // WebSocket: receive live element pushes from Neovim
  useEffect(() => {
    const connect = () => {
      const ws = new WebSocket('ws://' + window.location.host)
      wsRef.current = ws

      ws.addEventListener('message', e => {
        if (!apiRef.current) return
        try {
          const msg = JSON.parse(e.data)

          if (msg.type === 'element:add') {
            const current = apiRef.current.getSceneElements()
            const ids     = new Set(current.map(el => el.id))
            const fresh   = msg.elements.filter(el => !ids.has(el.id))
            if (fresh.length > 0) {
              apiRef.current.updateScene({ elements: [...current, ...fresh] })
            }
          }

          if (msg.type === 'board:init' && !initialized.current && msg.elements?.length > 0) {
            initialized.current = true
            apiRef.current.updateScene({ elements: msg.elements, appState: msg.appState || {} })
          }
        } catch (_) {}
      })

      ws.addEventListener('close', () => {
        // Reconnect after 2s if the server restarts
        setTimeout(connect, 2000)
      })
    }

    connect()
    return () => wsRef.current?.close()
  }, [])

  // Debounced save: persist board 1s after the last user edit
  const onChange = useCallback((elements, appState) => {
    clearTimeout(saveTimer.current)
    saveTimer.current = setTimeout(() => {
      fetch('/api/board', {
        method:  'PUT',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({
          elements: elements.filter(el => !el.isDeleted),
          appState: {
            zoom:    appState.zoom,
            scrollX: appState.scrollX,
            scrollY: appState.scrollY,
          },
        }),
      }).catch(console.error)
    }, 1000)
  }, [])

  return (
    <div style={{ width: '100%', height: '100vh' }}>
      <Excalidraw
        excalidrawAPI={api => { apiRef.current = api }}
        onChange={onChange}
        theme="light"
        UIOptions={{
          canvasActions: {
            loadScene:  false,
            saveScene:  false,
            saveToActiveFile: false,
          },
        }}
      />
    </div>
  )
}

createRoot(document.getElementById('root')).render(<App />)
