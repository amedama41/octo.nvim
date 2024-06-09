local OctoBuffer = require("octo.model.octo-buffer").OctoBuffer
local utils = require "octo.utils"

local M = {}

function M.show_review_threads()
  -- Check if we are in a diff buffer and otherwise return early
  local bufnr = vim.api.nvim_get_current_buf()
  local split, path = utils.get_split_and_path(bufnr)
  if not split or not path then
    -- not on a diff buffer
    return
  end

  local review = require("octo.reviews").get_current_review()
  if not review then
    -- cant find an active review
    return
  end

  local file = review.layout:cur_file()
  if not file then
    -- cant find the changed file metadata
    return
  end

  local pr = file.pull_request
  local review_level = review:get_level()
  local threads = vim.tbl_values(review.threads)
  local line = vim.api.nvim_win_get_cursor(0)[1]

  -- get threads associated with current line
  local threads_at_cursor = {}
  for _, thread in ipairs(threads) do
    if
      review_level == "PR"
      and utils.is_thread_placed_in_buffer(thread, bufnr)
      and thread.startLine <= line
      and thread.line >= line
    then
      table.insert(threads_at_cursor, thread)
    elseif review_level == "COMMIT" then
      local commit
      if split == "LEFT" then
        commit = review.layout.left.commit
      else
        commit = review.layout.right.commit
      end
      for _, comment in ipairs(thread.comments.nodes) do
        if commit == comment.originalCommit.oid and thread.originalLine == line then
          table.insert(threads_at_cursor, thread)
          break
        end
      end
    end
  end

  -- render thread buffer if there are threads at the current line
  if #threads_at_cursor > 0 then
    review.layout:ensure_layout()
    local alt_win = file:get_alternative_win(split)
    local thread_buffer = M.create_thread_buffer(threads_at_cursor, pr.repo, pr.number, split, file.path)
    if thread_buffer then
      table.insert(file.associated_bufs, thread_buffer.bufnr)
      local thread_winid = review.layout.thread_winid
      if thread_winid == -1 or not vim.api.nvim_win_is_valid(thread_winid) then
        review.layout.thread_winid = vim.api.nvim_open_win(
          thread_buffer.bufnr, true, {
            relative = "win",
            win = alt_win,
            anchor = "NW",
            width = vim.api.nvim_win_get_width(alt_win) - 4,
            height = vim.api.nvim_win_get_height(alt_win) - 4,
            row = 1,
            col = 1,
            border = "single",
            zindex = 3,
          }
        )
        vim.wo[review.layout.thread_winid].winhighlight = vim.iter({
          "NormalFloat:OctoThreadPanelFloat",
          "FloatBorder:OctoThreadPanelFloatBoarder",
          "SignColumn:OctoThreadPanelSignColumn",
        }):join(",")
      else
        vim.api.nvim_win_set_buf(thread_winid, thread_buffer.bufnr)
      end
      thread_buffer:configure()
      vim.api.nvim_buf_call(thread_buffer.bufnr, function()
        pcall(vim.cmd, "normal ]c")
      end)
    end
  else
    -- no threads at the current line, hide the thread buffer
    local thread_winid = review.layout.thread_winid
    if thread_winid ~= -1 or vim.api.nvim_win_is_valid(thread_winid) then
      vim.api.nvim_win_close(thread_winid, true)
      review.layout.thread_winid = -1
    end
  end
end

function M.hide_review_threads()
  local review = require("octo.reviews").get_current_review()
  if not review then
    -- cant find an active review
    return
  end

  local thread_winid = review.layout.thread_winid
  if thread_winid ~= -1 or vim.api.nvim_win_is_valid(thread_winid) then
    vim.api.nvim_win_close(thread_winid, true)
    review.layout.thread_winid = -1
  end
end

function M.create_thread_buffer(threads, repo, number, side, path)
  local current_review = require("octo.reviews").get_current_review()
  if not vim.startswith(path, "/") then
    path = "/" .. path
  end
  local line = threads[1].originalStartLine ~= vim.NIL and threads[1].originalStartLine or threads[1].originalLine
  local bufname = string.format("octo://%s/review/%s/threads/%s%s:%d", repo, current_review.id, side, path, line)
  local bufnr = vim.fn.bufnr(bufname)
  local buffer
  if bufnr == -1 then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, bufname)
    buffer = OctoBuffer:new {
      bufnr = bufnr,
      number = number,
      repo = repo,
    }
    buffer:render_threads(threads)
    buffer:render_signcolumn()
  elseif vim.api.nvim_buf_is_loaded(bufnr) then
    buffer = octo_buffers[bufnr]
  else
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  return buffer
end

return M
