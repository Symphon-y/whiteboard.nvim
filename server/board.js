'use strict'

const fs   = require('fs')
const path = require('path')
const crypto = require('crypto')

const DEFAULT_STATE = () => ({
  elements:     [],
  appState:     {},
  nextPosition: { x: 60, y: 60 },
  _col:         0,
})

function load(boardPath) {
  try {
    const raw = fs.readFileSync(boardPath, 'utf8')
    const data = JSON.parse(raw)
    // _col is transient — recompute from element count on load
    data._col = data._col || 0
    return data
  } catch (_) {
    return DEFAULT_STATE()
  }
}

function save(boardPath, state) {
  fs.mkdirSync(path.dirname(boardPath), { recursive: true })
  // Strip transient field before persisting
  const { _col, ...persisted } = state
  fs.writeFileSync(boardPath, JSON.stringify(persisted), 'utf8')
}

// Assign real UUIDs and positions to incoming elements, mutate state,
// save to disk, and return the placed elements for WebSocket broadcast.
function addElements(state, incoming, boardPath) {
  if (!incoming || incoming.length === 0) return []

  // Detect card dimensions from _cardMeta on the first element
  const meta       = incoming[0]._cardMeta || {}
  const cardWidth  = meta.cardWidth  || 300
  const cardHeight = meta.cardHeight || 120

  const cardsPerRow = 4
  const colGap      = 40
  const rowGap      = 40

  // Determine placement position
  const pos = { x: state.nextPosition.x, y: state.nextPosition.y }

  // Advance position for next card
  state._col = (state._col || 0) + 1
  if (state._col >= cardsPerRow) {
    state.nextPosition.x  = 60
    state.nextPosition.y += cardHeight + rowGap
    state._col            = 0
  } else {
    state.nextPosition.x += cardWidth + colGap
  }

  // Generate a shared groupId for all elements in this card
  const groupId = crypto.randomUUID()

  const placed = incoming.map((el, i) => {
    // Strip internal meta, replace placeholder groupId, assign real UUID and position
    const { _cardMeta, groupIds, id, x, y, ...rest } = el
    return {
      id:       crypto.randomUUID(),
      x:        pos.x + (x || 0),
      y:        pos.y + (y || 0),
      groupIds: [groupId],
      ...rest,
    }
  })

  state.elements.push(...placed)
  save(boardPath, state)

  return placed
}

module.exports = { load, save, addElements }
