local Layout = require("octo.reviews.layout").Layout
local Rev = require("octo.reviews.rev").Rev
local config = require "octo.config"
local gh = require "octo.gh"
local graphql = require "octo.gh.graphql"
local thread_panel = require "octo.reviews.thread-panel"
local window = require "octo.ui.window"
local utils = require "octo.utils"

---@class Review
---@field repo string
---@field number integer
---@field id string|nil
---@field threads PullRequestReviewThread[]
---@field files FileEntry[]
---@field layout Layout
---@field pull_request OctoPullRequest
local Review = {}
Review.__index = Review

---Review constructor.
---@param pull_request OctoPullRequest
---@return Review
function Review:new(pull_request)
  local this = {
    pull_request = pull_request,
    id = nil,
    threads = {},
    files = {},
  }
  setmetatable(this, self)
  return this
end

-- Creates a new review
---@param callback fun(resp: StartReviewMutationResponse)
function Review:create(callback)
  local query = graphql("start_review_mutation", self.pull_request.id)
  gh.run {
    args = { "api", "graphql", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        ---@type StartReviewMutationResponse
        local resp = vim.fn.json_decode(output)
        callback(resp)
      end
    end,
  }
end

-- Starts a new review
function Review:start()
  self:create(function(resp)
    self.id = resp.data.addPullRequestReview.pullRequestReview.id
    local threads = resp.data.addPullRequestReview.pullRequestReview.pullRequest.reviewThreads.nodes
    self:update_threads(threads)
    local pull_request = resp.data.addPullRequestReview.pullRequestReview.pullRequest
    local left = Rev:new(pull_request.baseRefOid)
    local right = Rev:new(pull_request.headRefOid)
    self.pull_request:update(left, right, pull_request.files.nodes)
    self:initiate()
  end)
end

-- Retrieves existing review
---@param callback fun(resp: PendingReviewThreadsQueryResponse)
function Review:retrieve(callback)
  local query =
    graphql("pending_review_threads_query", self.pull_request.owner, self.pull_request.name, self.pull_request.number)
  gh.run {
    args = { "api", "graphql", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        ---@type PendingReviewThreadsQueryResponse
        local resp = vim.fn.json_decode(output)
        callback(resp)
      end
    end,
  }
end

-- Resumes an existing review
function Review:resume()
  self:retrieve(function(resp)
    if #resp.data.repository.pullRequest.reviews.nodes == 0 then
      utils.error "No pending reviews found"
      return
    end

    local reviews = resp.data.repository.pullRequest.reviews.nodes
    assert(reviews ~= nil)
    -- There can only be one pending review for a given user
    for _, review in ipairs(reviews) do
      if review.viewerDidAuthor then
        self.id = review.id
        break
      end
    end

    if not self.id then
      vim.error "No pending reviews found for viewer"
      return
    end

    ---@type PullRequestReviewThread[]
    local threads = resp.data.repository.pullRequest.reviewThreads.nodes
    self:update_threads(threads)
    local pull_request = resp.data.repository.pullRequest
    local left = Rev:new(pull_request.baseRefOid)
    local right = Rev:new(pull_request.headRefOid)
    self.pull_request:update(left, right, pull_request.files.nodes)
    self:initiate()
  end)
end

-- Updates layout to focus on a single commit
---@param right string
---@param left string
function Review:focus_commit(right, left)
  local pr = self.pull_request
  self.layout:close()
  self.layout = Layout:new {
    right = Rev:new(right),
    left = Rev:new(left),
    files = {},
  }
  self.layout:open(self)
  ---@param files FileEntry[]
  local cb = function(files)
    -- pre-fetch the first file
    if #files > 0 then
      files[1]:fetch()
    end
    self.layout.files = files
    self.layout:update_files()
  end
  if right == self.pull_request.right.commit and left == self.pull_request.left.commit then
    pr:get_changed_files(cb)
  else
    pr:get_commit_changed_files(self.layout.right, cb)
  end
end

---Initiates (starts/resumes) a review
function Review:initiate()
  local pr = self.pull_request
  local conf = config.values
  if conf.use_local_fs and not utils.in_pr_branch(pr.bufnr, pr.right.commit) then
    local choice = vim.fn.confirm("Currently not in PR branch, would you like to checkout?", "&Yes\n&No", 2)
    if choice == 1 then
      utils.checkout_pr_sync(pr.number)
    end
  end

  local cmd = {"git", "merge-base", pr.left.commit, pr.right.commit}
  local result = vim.system(cmd, { text = true }):wait()
  if result.code ~= 0 then
    utils.error "not resolve merge base"
    pr.merge_base = pr.left
  else
    local merge_base = vim.trim(result.stdout)
    pr.merge_base = Rev:new(merge_base)
  end

  -- create the layout
  self.layout = Layout:new {
    -- TODO: rename to left_rev and right_rev
    left = pr.merge_base,
    right = pr.right,
    files = {},
  }
  self.layout:open(self)

  pr:get_changed_files(function(files)
    -- pre-fetch the first file
    if #files > 0 then
      files[1]:fetch()
    end
    self.layout.files = files
    self.layout:update_files()
  end)
end

function Review:discard()
  local query =
    graphql("pending_review_threads_query", self.pull_request.owner, self.pull_request.name, self.pull_request.number)
  gh.run {
    args = { "api", "graphql", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        vim.error(stderr)
      elseif output then
        ---@type PendingReviewThreadsQueryResponse
        local resp = vim.fn.json_decode(output)
        if #resp.data.repository.pullRequest.reviews.nodes == 0 then
          utils.error "No pending reviews found"
          return
        end
        self.id = resp.data.repository.pullRequest.reviews.nodes[1].id

        local choice = vim.fn.confirm("All pending comments will get deleted, are you sure?", "&Yes\n&No\n&Cancel", 2)
        if choice == 1 then
          local delete_query = graphql("delete_pull_request_review_mutation", self.id)
          gh.run {
            args = { "api", "graphql", "-f", string.format("query=%s", delete_query) },
            cb = function(del_output, del_stderr)
              if del_stderr and not utils.is_blank(del_stderr) then
                vim.error(del_stderr)
              elseif del_output then
                self.id = nil
                self.threads = {}
                self.files = {}
                utils.info "Pending review discarded"
                vim.cmd [[tabclose]]
              end
            end,
          }
        end
      end
    end,
  }
end

---@param threads PullRequestReviewThread[]
function Review:update_threads(threads)
  self.threads = {}
  for _, thread in ipairs(threads) do
    if thread.line == vim.NIL then
      thread.line = thread.originalLine
    end
    if thread.startLine == vim.NIL then
      thread.startLine = thread.line
      thread.startDiffSide = thread.diffSide
      thread.originalStartLine = thread.originalLine
    end
    self.threads[thread.id] = thread
  end
  if self.layout then
    self.layout.file_panel:render()
    self.layout.file_panel:redraw()
    if self.layout:cur_file() then
      self.layout:cur_file():place_signs()
    end
  end
end

function Review:collect_submit_info()
  if not self.id then
    utils.error "No review in progress"
    return
  end

  local conf = config.values
  local winid, bufnr = window.create_centered_float {
    header = string.format(
      "Press %s to approve, %s to comment or %s to request changes",
      conf.mappings.submit_win.approve_review.lhs,
      conf.mappings.submit_win.comment_review.lhs,
      conf.mappings.submit_win.request_changes.lhs
    ),
  }
  vim.api.nvim_set_current_win(winid)
  vim.api.nvim_set_option_value("syntax", "octo", { buf = bufnr })
  utils.apply_mappings("submit_win", bufnr)
  vim.cmd [[normal G]]
end

function Review:submit(event)
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local body = utils.escape_char(utils.trim(table.concat(lines, "\n")))
  local query = graphql("submit_pull_request_review_mutation", self.id, event, body, { escape = false })
  gh.run {
    args = { "api", "graphql", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        utils.info "Review was submitted successfully!"
        pcall(vim.api.nvim_win_close, winid, 0)
        self.layout:close()
      end
    end,
  }
end

function Review:show_pending_comments()
  ---@type PullRequestReviewThread[]
  local pending_threads = {}
  ---@type PullRequestReviewThread[]
  local threads = vim.tbl_values(self.threads)
  table.sort(threads, function(t1, t2)
    return t1.startLine < t2.startLine
  end)
  for _, thread in ipairs(threads) do
    for _, comment in ipairs(thread.comments.nodes) do
      if comment.pullRequestReview.state == "PENDING" and not utils.is_blank(utils.trim(comment.body)) then
        table.insert(pending_threads, thread)
      end
    end
  end
  if #pending_threads == 0 then
    utils.error "No pending comments found"
    return
  else
    require("octo.pickers.telescope.provider").pending_threads(pending_threads)
  end
end

---@param is_suggestion boolean
function Review:add_comment(is_suggestion)
  -- check if we are on the diff layout and return early if not
  local bufnr = vim.api.nvim_get_current_buf()
  local split, path = utils.get_split_and_path(bufnr)
  if not split or not path then
    return
  end

  local file = self.layout:cur_file()
  if not file then
    return
  end

  -- get visual selected line range
  local line1, line2 = utils.get_lines_from_context "visual"

  local comment_ranges
  if split == "RIGHT" then
    comment_ranges = file.right_comment_ranges
  elseif split == "LEFT" then
    comment_ranges = file.left_comment_ranges
  else
    return
  end

  local diff_hunk
  -- for non-added files, check we are in a valid comment range
  if file.status ~= "A" then
    for i, range in ipairs(comment_ranges) do
      if range[1] <= line1 and range[2] >= line2 then
        diff_hunk = file.diffhunks[i]
        break
      end
    end
    if not diff_hunk then
      utils.error "Cannot place comments outside diff hunks"
      return
    end
    if not vim.startswith(diff_hunk, "@@") then
      diff_hunk = "@@ " .. diff_hunk
    end
  else
    local total_lines = vim.api.nvim_buf_line_count(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, line2, true)
    diff_hunk = ("@@ -0,0 +1,%d @@\n"):format(total_lines) .. vim.iter(lines):map(function(line)
      return "+" .. line
    end):join("\n")
  end

  self.layout:ensure_layout()

  self:show_new_thread_panel(file, "LINE", split, line1, line2, diff_hunk, is_suggestion)
end

function Review:add_file_comment()
  -- check if we are on the diff layout and return early if not
  self.layout:ensure_layout()

  local file = self.layout.file_panel:get_file_at_cursor()
  if not file then
    return
  end

  self:show_new_thread_panel(file, "FILE", "RIGHT", 1, 1, "", false)
end

---@private
---@param file FileEntry
---@param subjectType PullRequestReviewThreadSubjectType
---@param split DiffSide
---@param line1 integer
---@param line2 integer
---@param diff_hunk string
---@param is_suggestion boolean
function Review:show_new_thread_panel(file, subjectType, split, line1, line2, diff_hunk, is_suggestion)
  local cur_file = self.layout:cur_file()
  if not cur_file then
    return
  end

  local alt_win = cur_file:get_alternative_win(split)
  if vim.api.nvim_win_is_valid(alt_win) then
    local pr = file.pull_request

    -- create a thread stub representing the new comment

    local commit, commit_abbrev
    if split == "LEFT" then
      commit = self.layout.left.commit
      commit_abbrev = self.layout.left:abbrev()
    elseif split == "RIGHT" then
      commit = self.layout.right.commit
      commit_abbrev = self.layout.right:abbrev()
    end
    ---@type PullRequestReviewThread[]
    local threads = {
      {
        originalStartLine = line1,
        originalLine = line2,
        path = file.path,
        isOutdated = false,
        isResolved = false,
        diffSide = split,
        startDiffSide = split,
        isCollapsed = false,
        id = "",
        subjectType = subjectType,
        comments = {
          nodes = {
            {
              id = "",
              path = file.path,
              subjectType = subjectType,
              author = { login = vim.g.octo_viewer },
              authorAssociation = "NONE",
              state = "PENDING",
              replyTo = vim.NIL,
              url = vim.NIL,
              diffHunk = diff_hunk,
              createdAt = vim.fn.strftime "%FT%TZ",
              originalCommit = { oid = commit, abbreviatedOid = commit_abbrev },
              body = "",
              viewerCanUpdate = true,
              viewerCanDelete = true,
              viewerDidAuthor = true,
              pullRequestReview = { id = self.id },
              reactionGroups = {
                { content = "THUMBS_UP", users = { totalCount = 0 }, viewerHasReacted = false },
                { content = "THUMBS_DOWN", users = { totalCount = 0 }, viewerHasReacted = false },
                { content = "LAUGH", users = { totalCount = 0 }, viewerHasReacted = false },
                { content = "HOORAY", users = { totalCount = 0 }, viewerHasReacted = false },
                { content = "CONFUSED", users = { totalCount = 0 }, viewerHasReacted = false },
                { content = "HEART", users = { totalCount = 0 }, viewerHasReacted = false },
                { content = "ROCKET", users = { totalCount = 0 }, viewerHasReacted = false },
                { content = "EYES", users = { totalCount = 0 }, viewerHasReacted = false },
              },
            },
          },
        },
      },
    }

    -- TODO: if there are threads for that line, there should be a buffer already showing them
    -- or maybe not if the user is very quick
    local thread_buffer = thread_panel.create_thread_buffer(1, threads, pr.repo, pr.number, split, file.path)
    if thread_buffer then
      table.insert(file.associated_bufs, thread_buffer.bufnr)
      local thread_winid = self.layout.thread_winid
      if thread_winid == -1 or not vim.api.nvim_win_is_valid(thread_winid) then
        self.layout.thread_winid = vim.api.nvim_open_win(thread_buffer.bufnr, true, {
          relative = "win",
          win = alt_win,
          anchor = "NW",
          width = vim.api.nvim_win_get_width(alt_win) - 4,
          height = vim.api.nvim_win_get_height(alt_win) - 4,
          row = 1,
          col = 1,
          border = "single",
          zindex = 3,
        })
        vim.wo[self.layout.thread_winid].winhighlight = vim
          .iter({
            "NormalFloat:OctoThreadPanelFloat",
            "FloatBorder:OctoThreadPanelFloatBoarder",
            "SignColumn:OctoThreadPanelSignColumn",
          })
          :join ","
      else
        vim.api.nvim_win_set_buf(thread_winid, thread_buffer.bufnr)
      end
      if is_suggestion then
        local current_bufnr
        if split == "RIGHT" then
          current_bufnr = file.right_bufid
        elseif split == "LEFT" then
          current_bufnr = file.left_bufid
        end
        local lines = vim.api.nvim_buf_get_lines(current_bufnr, line1 - 1, line2, false)
        local suggestion = { "```suggestion" }
        vim.list_extend(suggestion, lines)
        table.insert(suggestion, "```")
        vim.api.nvim_buf_set_lines(thread_buffer.bufnr, -3, -2, false, suggestion)
        vim.api.nvim_set_option_value("modified", false, { buf = thread_buffer.bufnr })
      end
      thread_buffer:configure()
      vim.cmd [[normal! vvGk]]
      vim.cmd [[startinsert]]
    end
  else
    utils.error("Cannot find diff window " .. alt_win)
  end
end

---@return "COMMIT"|"PR"
function Review:get_level()
  local review_level = "COMMIT"
  if
    self.layout.left.commit == self.pull_request.merge_base.commit
    and self.layout.right.commit == self.pull_request.right.commit
  then
    review_level = "PR"
  end
  return review_level
end

local M = {}

M.reviews = {}

M.Review = Review

---@param is_suggestion boolean
function M.add_review_comment(is_suggestion)
  local review = M.get_current_review()
  if review == nil then
    return
  end
  if review.layout.file_panel:is_focused() then
    review:add_file_comment()
  else
    review:add_comment(is_suggestion)
  end
end

---@param thread PullRequestReviewThread
function M.jump_to_pending_review_thread(thread)
  local current_review = M.get_current_review()
  if current_review == nil then
    return
  end
  for _, file in ipairs(current_review.layout.files) do
    if thread.path == file.path then
      current_review.layout:ensure_layout()
      current_review.layout:set_file(file)
      local win = file:get_win(thread.diffSide)
      if vim.api.nvim_win_is_valid(win) then
        local review_level = current_review:get_level()
        -- jumping to the original position in case we are reviewing any commit
        -- jumping to the PR position if we are reviewing the last commit
        -- This may result in a jump to the wrong line when the review is neither in the last commit or the original one
        local line = review_level == "COMMIT" and thread.originalStartLine or thread.startLine
        vim.api.nvim_set_current_win(win)
        vim.api.nvim_win_set_cursor(win, { line, 0 })
      else
        utils.error "Cannot find diff window"
      end
      break
    end
  end
end

---@return Review?
function M.get_current_review()
  local current_tabpage = vim.api.nvim_get_current_tabpage()
  return M.reviews[tostring(current_tabpage)]
end

---@return Layout?
function M.get_current_layout()
  local current_review = M.get_current_review()
  if current_review then
    return current_review.layout
  end
end

function M.on_tab_leave()
  local current_review = M.get_current_review()
  if current_review and current_review.layout then
    current_review.layout:on_leave()
  end
end

function M.on_win_leave()
  local current_review = M.get_current_review()
  if current_review and current_review.layout then
    current_review.layout:on_win_leave()
  end
end

function M.close(tabpage)
  if tabpage then
    local review = M.reviews[tostring(tabpage)]
    if review and review.layout then
      review.layout:close()
    end
    M.reviews[tostring(tabpage)] = nil
  end
end

function M.start_review()
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if not buffer then
    utils.error "No Octo buffer found"
    return
  end
  local pull_request = buffer:get_pr()
  if pull_request then
    local current_review = Review:new(pull_request)
    current_review:start()
  else
    pull_request = utils.get_pull_request_for_current_branch(function(pr)
      local current_review = Review:new(pr)
      current_review:start()
    end)
  end
end

function M.resume_review()
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if not buffer then
    utils.error "No Octo buffer found"
    return
  end
  local pull_request = buffer:get_pr()
  if pull_request then
    local current_review = Review:new(pull_request)
    current_review:resume()
  else
    pull_request = utils.get_pull_request_for_current_branch(function(pr)
      local current_review = Review:new(pr)
      current_review:resume()
    end)
  end
end

function M.discard_review()
  local current_review = M.get_current_review()
  if current_review then
    current_review:discard()
  else
    utils.error "Please start or resume a review first"
  end
end

function M.submit_review()
  local current_review = M.get_current_review()
  if current_review then
    current_review:collect_submit_info()
  else
    utils.error "Please start or resume a review first"
  end
end

return M
