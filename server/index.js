'use strict'

const http   = require('http')
const fs     = require('fs')
const path   = require('path')
const { WebSocketServer } = require('ws')
const board  = require('./board')

// --- Parse CLI arguments ---
const args = process.argv.slice(2)
function arg(name) {
  const i = args.indexOf('--' + name)
  return i !== -1 ? args[i + 1] : null
}

const repoRoot   = arg('repo')       || process.cwd()
const dataDir    = arg('data-dir')   || path.join(require('os').homedir(), '.local', 'share', 'nvim')
const port       = parseInt(arg('port') || '0', 10)
const background = arg('background') || '#f0f0f0'

// --- Board path (mirrors repo.lua's board_path logic) ---
const crypto    = require('crypto')
const repoHash  = crypto.createHash('sha256').update(repoRoot).digest('hex').slice(0, 16)
const boardDir  = path.join(dataDir, 'whiteboard', 'boards')
const boardPath = path.join(boardDir, repoHash + '.json')

// Load board state once at startup; mutated in-place by addElements / PUT /api/board
const state = board.load(boardPath)

// Set background for new boards (existing boards keep their persisted appState)
if (!state.appState.viewBackgroundColor) {
  state.appState.viewBackgroundColor = background
}

// --- Static file serving ---
const PUBLIC = path.join(__dirname, 'public')
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'application/javascript; charset=utf-8',
  '.css':  'text/css; charset=utf-8',
}

function serveFile(res, filePath) {
  try {
    const body = fs.readFileSync(filePath)
    const ext  = path.extname(filePath)
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' })
    res.end(body)
  } catch (_) {
    res.writeHead(404).end('not found')
  }
}

// --- Read full request body ---
function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = ''
    req.on('data', chunk => { body += chunk })
    req.on('end',  ()    => resolve(body))
    req.on('error', reject)
  })
}

// --- HTTP server ---
const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type')

  if (req.method === 'OPTIONS') {
    res.writeHead(204).end()
    return
  }

  const url = req.url.split('?')[0]

  if (req.method === 'GET' && url === '/') {
    return serveFile(res, path.join(PUBLIC, 'index.html'))
  }

  if (req.method === 'GET' && url === '/app.js') {
    return serveFile(res, path.join(PUBLIC, 'app.js'))
  }

  if (req.method === 'GET' && url === '/api/board') {
    res.writeHead(200, { 'Content-Type': 'application/json' })
    return res.end(JSON.stringify(state))
  }

  if (req.method === 'POST' && url === '/api/elements') {
    try {
      const body    = await readBody(req)
      const { elements } = JSON.parse(body)
      const placed  = board.addElements(state, elements, boardPath)
      broadcast({ type: 'element:add', elements: placed })
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify({ ok: true, count: placed.length }))
    } catch (e) {
      res.writeHead(400).end(String(e))
    }
    return
  }

  if (req.method === 'PUT' && url === '/api/board') {
    try {
      const body     = await readBody(req)
      const incoming = JSON.parse(body)
      if (incoming.elements) state.elements = incoming.elements
      if (incoming.appState) state.appState = incoming.appState
      board.save(boardPath, state)
      res.writeHead(200).end('ok')
    } catch (e) {
      res.writeHead(400).end(String(e))
    }
    return
  }

  res.writeHead(404).end('not found')
})

// --- WebSocket ---
const wss = new WebSocketServer({ server })

function broadcast(msg) {
  const json = JSON.stringify(msg)
  wss.clients.forEach(ws => {
    if (ws.readyState === ws.OPEN) ws.send(json)
  })
}

wss.on('connection', ws => {
  // Send the full board to any newly connected browser
  ws.send(JSON.stringify({ type: 'board:init', elements: state.elements, appState: state.appState }))

  // Handle messages FROM the browser (e.g. card link clicks)
  ws.on('message', data => {
    try {
      const msg = JSON.parse(data)
      if (msg.type === 'neovim:open') {
        // Relay to Lua via stdout; server.lua's on_stdout parses CMD: lines
        process.stdout.write('CMD:' + JSON.stringify({
          type: 'open',
          path: msg.path,
          line: msg.line || 0,
        }) + '\n')
      }
    } catch (_) {}
  })
})

// --- Start ---
server.listen(port, '127.0.0.1', () => {
  // Lua reads this sentinel from stdout to know the port
  process.stdout.write('LISTENING:' + server.address().port + '\n')
})

process.on('SIGTERM', () => server.close())
process.on('SIGINT',  () => server.close())
