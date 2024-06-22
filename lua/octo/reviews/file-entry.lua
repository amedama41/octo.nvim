-- Heavily derived from `diffview.nvim`:
-- https://github.com/sindrets/diffview.nvim/blob/main/lua/diffview/file-entry.lua

local config = require "octo.config"
local constants = require "octo.constants"
local gh = require "octo.gh"
local graphql = require "octo.gh.graphql"
local utils = require "octo.utils"
local vim = vim

local M = {}

---@type table<string, integer>
M._null_buffer = {}

---@class GitStats
---@field additions integer
---@field deletions integer
---@field changes integer

---@class FileEntry
---@field path string
---@field previous_path string?
---@field basename string
---@field extension string
---@field pull_request PullRequest
---@field status string
---@field patch string?
---@field stats GitStats
---@field left_binary boolean|nil
---@field right_binary boolean|nil
---@field left_bufid integer
---@field right_bufid integer
---@field left_lines string[]
---@field right_lines string[]
---@field left_winid number
---@field right_winid number
---@field left_comment_ranges table
---@field right_comment_ranges table
---@field associated_bufs integer[]
---@field diffhunks string[]
---@field viewed_state string
local FileEntry = {}
FileEntry.__index = FileEntry

FileEntry.winopts = {
  foldmethod = "diff",
  foldlevel = 0,
}

---@class FileEntryOpt
---@field pull_request PullRequest
---@field path string
---@field previous_path string?
---@field patch string?
---@field status "A"|"D"|"M"|"R"
---@field stats { additions: integer, deletions: integer, changes: integer }
---@field left_binary boolean?
---@field right_binary boolean?

---FileEntry constructor
---@param opt FileEntryOpt
---@return FileEntry
function FileEntry:new(opt)
  local pr = opt.pull_request
  local diffhunks, left_ranges, right_ranges
  if opt.patch then
    diffhunks, left_ranges, right_ranges = utils.process_patch(opt.patch)
  end

  local this = {
    path = opt.path,
    previous_path = opt.previous_path,
    patch = opt.patch,
    basename = utils.path_basename(opt.path),
    extension = utils.path_extension(opt.path),
    pull_request = pr,
    status = opt.status,
    stats = opt.stats,
    left_comment_ranges = left_ranges,
    right_comment_ranges = right_ranges,
    left_binary = opt.left_binary,
    right_binary = opt.right_binary,
    diffhunks = diffhunks,
    associated_bufs = {},
    viewed_state = pr.files[opt.path],
  }
  if not this.status then
    this.status = " "
  end

  setmetatable(this, self)

  return this
end

---FileEntry toggle_viewed
function FileEntry:toggle_viewed()
  local query, next_state
  if self.viewed_state == "VIEWED" then
    query = graphql("unmark_file_as_viewed_mutation", self.path, self.pull_request.id)
    next_state = "UNVIEWED"
  elseif self.viewed_state == "UNVIEWED" then
    query = graphql("mark_file_as_viewed_mutation", self.path, self.pull_request.id)
    next_state = "VIEWED"
  elseif self.viewed_state == "DISMISSED" then
    query = graphql("mark_file_as_viewed_mutation", self.path, self.pull_request.id)
    next_state = "VIEWED"
  end
  gh.run {
    args = { "api", "graphql", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        vim.api.nvim_err_writeln(stderr)
      elseif output then
        --local resp = vim.fn.json_decode(output)
        self.viewed_state = next_state
        local current_review = require("octo.reviews").get_current_review()
        if current_review then
          current_review.layout.file_panel:render()
          current_review.layout.file_panel:redraw()
        end
      end
    end,
  }
end

---FileEntry finalizer
function FileEntry:destroy()
  self:detach_buffers()
  for _, bn in ipairs(self.associated_bufs) do
    pcall(vim.api.nvim_buf_delete, bn, { force = true })
  end
end

---Get the window id for the alternative side of the provided buffer
---@param split "LEFT"|"RIGHT"
---@return integer
function FileEntry:get_alternative_win(split)
  if split:lower() == "left" then
    return self.right_winid
  elseif split:lower() == "right" then
    return self.left_winid
  end
  ---@diagnostic disable-next-line missing-return
  assert(false, "never reach here")
end

---Get the buffer id for the alternative side of the provided buffer
---@param split "LEFT"|"RIGHT"
---@return integer
function FileEntry:get_alternative_buf(split)
  if split:lower() == "left" then
    return self.right_bufid
  elseif split:lower() == "right" then
    return self.left_bufid
  end
  ---@diagnostic disable-next-line missing-return
  assert(false, "never reach here")
end

---Get the window id for the side of the provided buffer
---@param split "LEFT"|"RIGHT"
---@return integer
function FileEntry:get_win(split)
  if split:lower() == "left" then
    return self.left_winid
  elseif split:lower() == "right" then
    return self.right_winid
  end
  ---@diagnostic disable-next-line missing-return
  assert(false, "never reach here")
end

---Get the buffer id for the side of the provided buffer
---@param split "LEFT"|"RIGHT"
---@return integer?
function FileEntry:get_buf(split)
  if split:lower() == "left" then
    return self.left_bufid
  elseif split:lower() == "right" then
    return self.right_bufid
  end
end

---Fetch file content locally or from GitHub.
---@return boolean
function FileEntry:fetch()
  local right_path = self.path
  local left_path = self.path
  local current_review = require("octo.reviews").get_current_review()
  assert(current_review ~= nil)
  local right_sha = current_review.layout.right.commit
  local left_sha = current_review.layout.left.commit
  local right_abbrev = current_review.layout.right:abbrev()
  local left_abbrev = current_review.layout.left:abbrev()
  local conf = config.values

  -- handle renamed files
  if self.status == "R" and self.previous_path then
    left_path = assert(self.previous_path)
  end

  -- fetch right version
  if self.pull_request.local_right then
    utils.get_file_at_commit(right_path, right_sha, function(lines)
      self.right_lines = lines
    end)
  else
    utils.get_file_contents(self.pull_request.repo, right_abbrev, right_path, function(lines)
      self.right_lines = lines
    end)
  end

  -- fetch left version
  if self.pull_request.local_left then
    utils.get_file_at_commit(left_path, left_sha, function(lines)
      self.left_lines = lines
    end)
  else
    utils.get_file_contents(self.pull_request.repo, left_abbrev, left_path, function(lines)
      self.left_lines = lines
    end)
  end

  -- wait until we have both versions
  return vim.wait(conf.timeout, function()
    return self.left_lines and self.right_lines and true
  end)
end

---Load the buffers.
---@param left_winid integer
---@param right_winid integer
function FileEntry:load_buffers(left_winid, right_winid)
  local empty_files = #self.left_lines == 0 and #self.right_lines == 0
  local splits = {
    {
      winid = left_winid,
      bufid = self.left_bufid,
      lines = self.left_lines,
      pos = "left",
      binary = self.left_binary == true or empty_files,
    },
    {
      winid = right_winid,
      bufid = self.right_bufid,
      lines = self.right_lines,
      pos = "right",
      binary = self.right_binary == true or empty_files,
    },
  }

  -- configure diff buffers
  for _, split in ipairs(splits) do
    if not split.bufid or not vim.api.nvim_buf_is_loaded(split.bufid) then
      local conf = config.values
      local use_local = conf.use_local_fs and split.pos == "right" and utils.in_pr_branch(self.pull_request.bufnr)

      -- create buffer
      split.bufid = M._create_buffer {
        status = self.status,
        show_diff = self.patch ~= nil,
        path = self.path,
        split = split.pos,
        binary = split.binary,
        lines = split.lines,
        repo = self.pull_request.repo,
        use_local = use_local,
      }

      -- register new buffer
      table.insert(self.associated_bufs, split.bufid)
      self[split.pos .. "_bufid"] = split.bufid
      self[split.pos .. "_winid"] = split.winid
    end

    M._configure_buffer(split.bufid)
    vim.api.nvim_win_set_buf(split.winid, split.bufid)
  end

  -- show thread signs and virtual text
  self:place_signs()

  -- configure windows
  M._configure_windows(left_winid, right_winid)

  self:show_diff()
end

-- activate the diff between right and left panels
function FileEntry:show_diff()
  for _, bufid in ipairs { self.left_bufid, self.right_bufid } do
    vim.api.nvim_buf_call(bufid, function()
      pcall(vim.cmd --[[@as function]], [[filetype detect]])
      pcall(vim.cmd --[[@as function]], [[doau BufEnter]])
      pcall(vim.cmd --[[@as function]], [[diffthis]])
      -- Scroll to trigger the scrollbind and sync the windows. This works more
      -- consistently than calling `:syncbind`.
      pcall(vim.cmd --[[@as function]], [[exec "normal! \<c-y>"]])
    end)
  end
end

function FileEntry:attach_buffers()
  if self.left_bufid then
    M._configure_buffer(self.left_bufid)
  end
  if self.right_bufid then
    M._configure_buffer(self.right_bufid)
  end
end

function FileEntry:detach_buffers()
  if self.left_bufid then
    M._detach_buffer(self.left_bufid)
  end
  if self.right_bufid then
    M._detach_buffer(self.right_bufid)
  end
end

---Compare against another FileEntry.
---@param other FileEntry
---@return boolean
function FileEntry:compare(other)
  if self.stats and not other.stats then
    return false
  end
  if not self.stats and other.stats then
    return false
  end
  if self.stats and other.stats then
    if self.stats.additions ~= other.stats.additions or self.stats.deletions ~= other.stats.deletions then
      return false
    end
  end

  return (self.path == other.path and self.status == other.status)
end

---Update thread signs in diff buffers.
function FileEntry:place_signs()
  local conf = config.values
  local current_review = require("octo.reviews").get_current_review()
  if current_review == nil then
    return
  end

  local review_level = current_review:get_level()
  local splits = {
    {
      bufnr = self.left_bufid,
      comment_ranges = self.left_comment_ranges,
      commit = current_review.layout.left:abbrev(),
    },
    {
      bufnr = self.right_bufid,
      comment_ranges = self.right_comment_ranges,
      commit = current_review.layout.right:abbrev(),
    },
  }
  for _, split in ipairs(splits) do
    vim.api.nvim_buf_clear_namespace(split.bufnr, constants.OCTO_REVIEW_COMMENTS_NS, 0, -1)

    -- place comment range signs
    if split.comment_ranges then
      for _, range in ipairs(split.comment_ranges) do
        vim.api.nvim_buf_set_extmark(split.bufnr, constants.OCTO_REVIEW_COMMENTS_NS, range[1] - 1, -1, {
          end_row = range[2] - 1,
          strict = false,
          number_hl_group = "OctoGreen",
        })
      end
    end

    -- place thread comments signs and virtual text
    ---@type PullRequestReviewThread[]
    local threads = vim.tbl_values(current_review.threads)
    table.sort(threads, function(t1, t2)
      return t1.startLine < t2.startLine
    end)
    for _, thread in ipairs(threads) do
      local startLine, endLine = thread.startLine, thread.line
      if review_level == "COMMIT" then
        startLine = thread.originalLine
        endLine = thread.originalLine
      end

      local sign_hl_group = "OctoBlue"
      if thread.isOutdated then
        sign_hl_group = "OctoRed"
      elseif thread.isResolved then
        sign_hl_group = "OctoGreen"
      end

      for _, comment in ipairs(vim.iter(thread.comments.nodes):rev():totable()) do
        if comment.state == "PENDING" then
          sign_hl_group = "OctoYellow"
        end
        if
          (review_level == "PR" and utils.is_thread_placed_in_buffer(thread, split.bufnr))
          or (review_level == "COMMIT" and split.commit == comment.originalCommit.abbreviatedOid)
        then
          -- for lines between startLine and endLine, place the sign
          vim.api.nvim_buf_set_extmark(split.bufnr, constants.OCTO_REVIEW_COMMENTS_NS, startLine - 1, -1, {
            end_row = endLine - 1,
            strict = false,
            sign_text = conf.comment_icon,
            sign_hl_group = sign_hl_group,
          })

          -- place the virtual text only on first line
          local last_date = comment.lastEditedAt ~= vim.NIL and comment.lastEditedAt or comment.createdAt
          local vt_msg = string.format("%2d comments (%s)", #thread.comments.nodes, utils.format_date(last_date))
          local opts = {
            virt_text = { { vt_msg, "Comment" } },
            virt_text_pos = "right_align",
            -- adding the extmark below can fail if we are in the `COMMIT` review level and the commit contains thread comments
            -- that is why we set strict to `false` here to ignore this possible error
            strict = false,
          }
          vim.api.nvim_buf_set_extmark(split.bufnr, constants.OCTO_REVIEW_COMMENTS_NS, startLine - 1, -1, opts)
          -- break out to prevent duplicate extmarks for the current comment thread
          break
        end
      end
    end
  end
end

---@param opts { status: string, show_diff: boolean, path: string, split: "left"|"right", binary: boolean, lines: string[], repo: string, use_local: boolean }
---@return integer
function M._create_buffer(opts)
  local current_review = require("octo.reviews").get_current_review()
  assert(current_review ~= nil)
  local bufnr
  if opts.use_local then
    -- Use the file from the file system
    -- Pros: LSP powered
    -- Cons: we need to change to the commit branch
    bufnr = vim.fn.bufadd(opts.path)
  else
    bufnr = vim.api.nvim_create_buf(false, false)
    local bufname =
      string.format("octo://%s/review/%s/file/%s/%s", opts.repo, current_review.id, string.upper(opts.split), opts.path)
    vim.api.nvim_buf_set_name(bufnr, bufname)
    if opts.binary then
      vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Binary file" })
    elseif opts.status == "R" and not opts.show_diff then
      vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Renamed" })
    elseif opts.lines then
      vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, opts.lines)
    end
  end
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_buf_set_var(bufnr, "octo_diff_props", {
    path = opts.path,
    split = string.upper(opts.split),
  })
  return bufnr
end

---@param left_winid integer
---@param right_winid integer
function M.load_null_buffers(left_winid, right_winid)
  M.load_null_buffer(left_winid)
  M.load_null_buffer(right_winid)
end

---@param winid integer
function M.load_null_buffer(winid)
  local bn = M._get_null_buffer()
  if vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_set_buf(winid, bn)
  end
  M._configure_buffer(bn)
end

---@return integer
function M._get_null_buffer()
  local msg = "Loading ..."
  local bn = M._null_buffer[msg]
  if not bn or vim.api.nvim_buf_is_loaded(bn) then
    local nbn = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_lines(nbn, 0, -1, false, { msg })
    local bufname = utils.path_join { "octo", "null" }
    vim.api.nvim_set_option_value("modified", false, { buf = nbn })
    vim.api.nvim_set_option_value("modifiable", false, { buf = nbn })
    local ok = pcall(vim.api.nvim_buf_set_name, nbn, bufname)
    if not ok then
      utils.wipe_named_buffer(bufname)
      vim.api.nvim_buf_set_name(nbn, bufname)
    end
    M._null_buffer[msg] = nbn
  end
  return M._null_buffer[msg]
end

---@param left_winid integer
---@param right_winid integer
function M._configure_windows(left_winid, right_winid)
  for _, id in ipairs { left_winid, right_winid } do
    for k, v in pairs(FileEntry.winopts) do
      vim.api.nvim_set_option_value(k, v, { win = id })
    end
  end
end

---@param bufid integer
function M._configure_buffer(bufid)
  utils.apply_mappings("review_diff", bufid)
  -- local conf = config.values
  -- vim.cmd(string.format("nnoremap %s :OctoAddReviewComment<CR>", conf.mappings.review_thread.add_comment))
  -- vim.cmd(string.format("vnoremap %s :OctoAddReviewComment<CR>", conf.mappings.review_thread.add_comment))
  -- vim.cmd(string.format("nnoremap %s :OctoAddReviewSuggestion<CR>", conf.mappings.review_thread.add_suggestion))
  -- vim.cmd(string.format("vnoremap %s :OctoAddReviewSuggestion<CR>", conf.mappings.review_thread.add_suggestion))
end

---@param bufid integer
function M._detach_buffer(bufid)
  local conf = config.values
  for _, lhs in pairs(conf.mappings.review_diff) do
    pcall(vim.keymap.del, "n", lhs, { buffer = bufid })
  end
end

M.FileEntry = FileEntry

return M
