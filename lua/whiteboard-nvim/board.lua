-- whiteboard.board — pure Excalidraw element builders (no I/O, no network).
-- Positions are placeholder {x=0,y=0}; the server assigns real coordinates.
-- groupIds use a placeholder string; the server replaces them with real UUIDs.

local M = {}

local config = require('whiteboard-nvim.config')

local PLACEHOLDER_GROUP = 'WHITEBOARD_GROUP_PLACEHOLDER'

-- Percent-encode all characters that are not URL-safe alphanumerics.
local function url_encode(str)
  return (str:gsub('[^%w%-%.%_]', function(c)
    return string.format('%%%02X', string.byte(c))
  end))
end

local function base_element(type, x_off, y_off, w, h, extra)
  local el = {
    type            = type,
    x               = x_off,
    y               = y_off,
    width           = w,
    height          = h,
    angle           = 0,
    strokeColor     = '#1e1e1e',
    backgroundColor = 'transparent',
    fillStyle       = 'solid',
    strokeWidth     = 1,
    strokeStyle     = 'solid',
    roughness       = 0,
    opacity         = 100,
    groupIds        = { PLACEHOLDER_GROUP },
    frameId         = nil,
    seed            = math.random(1, 999999),
    version         = 1,
    versionNonce    = math.random(1, 999999),
    isDeleted       = false,
    boundElements   = nil,
    link            = nil,
    locked          = false,
  }
  if extra then
    for k, v in pairs(extra) do el[k] = v end
  end
  return el
end

local function rect(x_off, y_off, w, h, bg, stroke)
  return base_element('rectangle', x_off, y_off, w, h, {
    strokeColor     = stroke or '#adb5bd',
    backgroundColor = bg or '#ffffff',
    roundness       = { type = 3 },
  })
end

local function text_el(x_off, y_off, w, h, content, font_size, font_family, stroke_color)
  return base_element('text', x_off, y_off, w, h, {
    text           = content,
    fontSize       = font_size or 14,
    fontFamily     = font_family or 2,
    strokeColor    = stroke_color or '#1e1e1e',
    textAlign      = 'left',
    verticalAlign  = 'top',
    containerId    = nil,
    originalText   = content,
    lineHeight     = 1.25,
    autoResize     = true,
  })
end

-- Truncate a single line to max_len characters, appending '...' if cut.
local function truncate(line, max_len)
  max_len = max_len or 60
  if #line <= max_len then return line end
  return line:sub(1, max_len) .. '...'
end

-- Build code body text: truncate long lines and cap total lines.
local function format_code(lines, max_lines, max_col)
  max_lines = max_lines or 20
  max_col   = max_col   or 60
  local out = {}
  for i, line in ipairs(lines) do
    if i > max_lines then
      out[#out + 1] = '...'
      break
    end
    out[#out + 1] = truncate(line, max_col)
  end
  return table.concat(out, '\n')
end

-- File card: 3 elements — rectangle, filename text, path text.
-- opts = { filename, rel_path, abs_path? }
-- When abs_path is provided, the rectangle gets a whiteboard:// link so
-- clicking the card's link icon opens the file in Neovim.
function M.file_card(opts)
  local cfg = config.options.ui
  local w   = cfg.card_width
  local h   = cfg.card_height
  local pad = 12

  local bg_rect  = rect(0, 0, w, h, '#ffffff', '#adb5bd')
  local name_txt = text_el(pad, pad, w - pad * 2, 28, opts.filename, 20, 2, '#1e1e1e')
  local path_txt = text_el(pad, pad + 34, w - pad * 2, 16, opts.rel_path, 12, 2, '#868e96')

  if opts.abs_path then
    bg_rect.link = 'whiteboard://open?path=' .. url_encode(opts.abs_path) .. '&line=0'
  end

  -- _cardMeta carries sizing hints for the server's positioning algorithm.
  -- The server strips this field before persisting the board.
  bg_rect._cardMeta = { cardWidth = w, cardHeight = h }

  return { bg_rect, name_txt, path_txt }
end

-- Snippet card: 4 elements — rectangle, header, code body, "CODE" badge.
-- opts = { filename, rel_path, abs_path?, start_line, end_line, lines }
-- When abs_path is provided, clicking the link icon opens the file at start_line.
function M.snippet_card(opts)
  local cfg  = config.options.ui
  local w    = cfg.snippet_width
  local h    = cfg.snippet_height
  local pad  = 12
  local code = format_code(opts.lines)

  local header_text = opts.filename .. ':' .. opts.start_line .. '-' .. opts.end_line
  local badge_x     = w - pad - 36

  local bg_rect    = rect(0, 0, w, h, '#e7f5ff', '#339af0')
  local header_txt = text_el(pad, pad, w - pad * 3 - 36, 20, header_text, 14, 2, '#1e1e1e')
  local code_txt   = text_el(pad, pad + 26, w - pad * 2, h - pad * 2 - 26, code, 11, 3, '#495057')
  local badge_txt  = text_el(badge_x, pad + 2, 36, 14, 'CODE', 10, 2, '#339af0')

  if opts.abs_path then
    bg_rect.link = 'whiteboard://open?path=' .. url_encode(opts.abs_path)
                .. '&line=' .. opts.start_line
                .. '&end='  .. opts.end_line
  end

  bg_rect._cardMeta = { cardWidth = w, cardHeight = h }

  return { bg_rect, header_txt, code_txt, badge_txt }
end

return M
