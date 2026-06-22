import React, { useEffect, useRef, useCallback } from 'react'
import { createRoot } from 'react-dom/client'
import { Excalidraw, convertToExcalidrawElements } from '@excalidraw/excalidraw'

// Convert skeleton elements (from Neovim) to full Excalidraw elements.
// Safe to call on already-complete elements too.
function normalize(elements) {
  try {
    return convertToExcalidrawElements(elements)
  } catch (_) {
    return elements
  }
}

// Parse a whiteboard://open?path=...&line=N URL produced by board.lua.
function parseWhiteboardLink(link) {
  const match = link?.match(/^whiteboard:\/\/open\?(.+)$/)
  if (!match) return null
  const p = new URLSearchParams(match[1])
  return {
    path: decodeURIComponent(p.get('path') || ''),
    line: parseInt(p.get('line') || '0', 10),
    end:  parseInt(p.get('end')  || '0', 10),
  }
}

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
            elements: normalize(data.elements),
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
            const fresh   = normalize(msg.elements.filter(el => !ids.has(el.id)))
            if (fresh.length > 0) {
              apiRef.current.updateScene({ elements: [...current, ...fresh] })
            }
          }

          if (msg.type === 'board:init' && !initialized.current && msg.elements?.length > 0) {
            initialized.current = true
            apiRef.current.updateScene({
              elements: normalize(msg.elements),
              appState: msg.appState || {},
            })
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
            zoom:                appState.zoom,
            scrollX:             appState.scrollX,
            scrollY:             appState.scrollY,
            viewBackgroundColor: appState.viewBackgroundColor,
          },
        }),
      }).catch(console.error)
    }, 1000)
  }, [])

  // Intercept whiteboard:// links — send open command to Neovim via WS
  const onLinkOpen = useCallback((element, event) => {
    const parsed = parseWhiteboardLink(element.link)
    if (parsed && wsRef.current?.readyState === WebSocket.OPEN) {
      event.preventDefault()
      wsRef.current.send(JSON.stringify({
        type: 'neovim:open',
        path: parsed.path,
        line: parsed.line,
      }))
    }
  }, [])

  return (
    <div style={{ width: '100%', height: '100vh' }}>
      <Excalidraw
        excalidrawAPI={api => { apiRef.current = api }}
        onChange={onChange}
        onLinkOpen={onLinkOpen}
        theme="light"
        UIOptions={{
          canvasActions: {
            loadScene:        false,
            saveScene:        false,
            saveToActiveFile: false,
          },
        }}
      />
    </div>
  )
}

createRoot(document.getElementById('root')).render(<App />)
