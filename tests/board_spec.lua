local config = require('whiteboard-nvim.config')
config.setup({})

local board = require('whiteboard-nvim.board')

describe('whiteboard-nvim.board', function()
  describe('file_card', function()
    local els

    before_each(function()
      els = board.file_card({ filename = 'init.lua', rel_path = 'lua/foo/init.lua' })
    end)

    it('returns 3 elements', function()
      assert.are.equal(3, #els)
    end)

    it('first element is a rectangle', function()
      assert.are.equal('rectangle', els[1].type)
    end)

    it('all elements share the same placeholder groupId', function()
      local gid = els[1].groupIds[1]
      assert.is_not_nil(gid)
      assert.are.equal(gid, els[2].groupIds[1])
      assert.are.equal(gid, els[3].groupIds[1])
    end)

    it('filename appears in the second element', function()
      assert.are.equal('init.lua', els[2].text)
    end)

    it('relative path appears in the third element', function()
      assert.are.equal('lua/foo/init.lua', els[3].text)
    end)

    it('rectangle has white background', function()
      assert.are.equal('#ffffff', els[1].backgroundColor)
    end)

    it('positions start at origin (server will place them)', function()
      assert.are.equal(0, els[1].x)
      assert.are.equal(0, els[1].y)
    end)

    it('_cardMeta carries card dimensions', function()
      assert.is_not_nil(els[1]._cardMeta)
      assert.is_not_nil(els[1]._cardMeta.cardWidth)
      assert.is_not_nil(els[1]._cardMeta.cardHeight)
    end)
  end)

  describe('snippet_card', function()
    local els

    before_each(function()
      els = board.snippet_card({
        filename   = 'foo.lua',
        rel_path   = 'src/foo.lua',
        start_line = 10,
        end_line   = 15,
        lines      = { 'local x = 1', 'local y = 2', 'return x + y' },
      })
    end)

    it('returns 4 elements', function()
      assert.are.equal(4, #els)
    end)

    it('first element is a rectangle with blue tint', function()
      assert.are.equal('rectangle', els[1].type)
      assert.are.equal('#e7f5ff', els[1].backgroundColor)
    end)

    it('header text includes filename and line range', function()
      assert.is_truthy(els[2].text:find('foo%.lua'))
      assert.is_truthy(els[2].text:find('10%-15'))
    end)

    it('code body uses monospace fontFamily (3)', function()
      assert.are.equal(3, els[3].fontFamily)
    end)

    it('code body text contains the first line', function()
      assert.is_truthy(els[3].text:find('local x = 1', 1, true))
    end)

    it('truncates lines longer than 60 characters', function()
      local long = string.rep('x', 80)
      local long_els = board.snippet_card({
        filename = 'f.lua', rel_path = 'f.lua',
        start_line = 1, end_line = 1,
        lines = { long },
      })
      local code_body = long_els[3].text
      for line in (code_body .. '\n'):gmatch('([^\n]*)\n') do
        assert.is_true(#line <= 63, 'line too long: ' .. #line)
      end
    end)

    it('caps code body at 20 lines', function()
      local many = {}
      for i = 1, 30 do many[i] = 'line ' .. i end
      local long_els = board.snippet_card({
        filename = 'f.lua', rel_path = 'f.lua',
        start_line = 1, end_line = 30,
        lines = many,
      })
      local line_count = 0
      for _ in (long_els[3].text .. '\n'):gmatch('[^\n]*\n') do
        line_count = line_count + 1
      end
      assert.is_true(line_count <= 21, 'too many lines: ' .. line_count)
    end)
  end)
end)
