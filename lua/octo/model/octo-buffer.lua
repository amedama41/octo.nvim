local BodyMetadata = require("octo.model.body-metadata").BodyMetadata
local TitleMetadata = require("octo.model.title-metadata").TitleMetadata
local autocmds = require "octo.autocmds"
local config = require "octo.config"
local constants = require "octo.constants"
local folds = require "octo.folds"
local gh = require "octo.gh"
local graphql = require "octo.gh.graphql"
local signs = require "octo.ui.signs"
local writers = require "octo.ui.writers"
local utils = require "octo.utils"
local vim = vim

local M = {}

---@class OctoBuffer
---@field bufnr integer
---@field number integer?
---@field repo string?
---@field kind "pull"|"issue"|"repo"|"reviewthread"
---@field titleMetadata TitleMetadata
---@field bodyMetadata BodyMetadata
---@field commentsMetadata CommentMetadata[]
---@field threadsMetadata table<string, ThreadMetadata>
---@field node PullRequestWithReviewThreads|Issue|Repository?
---@field taggable_users string[]?
---@field owner string?
---@field name string?
local OctoBuffer = {}
OctoBuffer.__index = OctoBuffer

---@class OctoBufferOpts
---@field bufnr integer
---@field number integer?
---@field repo string?
---@field node PullRequestWithReviewThreads|Issue|Repository?
---@field commentsMetadata CommentMetadata[]?
---@field threadsMetadata ThreadMetadata[]?

---OctoBuffer constructor.
---@param opts OctoBufferOpts
---@return OctoBuffer
function OctoBuffer:new(opts)
  local this = {
    bufnr = opts.bufnr or vim.api.nvim_get_current_buf(),
    number = opts.number,
    repo = opts.repo,
    node = opts.node,
    titleMetadata = TitleMetadata:new(),
    bodyMetadata = BodyMetadata:new(),
    commentsMetadata = opts.commentsMetadata or {},
    threadsMetadata = opts.threadsMetadata or {},
  }
  if this.repo then
    this.owner, this.name = utils.split_repo(this.repo)
  end
  if this.node and this.node.commits then
    this.kind = "pull"
    this.taggable_users = { this.node.author.login }
  elseif this.node and this.number then
    this.kind = "issue"
    this.taggable_users = { this.node.author.login }
  elseif this.node and not this.number then
    this.kind = "repo"
  else
    this.kind = "reviewthread"
  end
  setmetatable(this, self)
  octo_buffers[this.bufnr] = this
  return this
end

M.OctoBuffer = OctoBuffer

---Apply the buffer mappings
function OctoBuffer:apply_mappings()
  ---@type OctoMappingsWindow
  local kind
  if self.kind == "pull" then
    kind = "pull_request"
  elseif self.kind == "reviewthread" then
    kind = "review_thread"
  else
    kind = self.kind --[[@as OctoMappingsWindow]]
  end
  utils.apply_mappings(kind, self.bufnr)
end

---Clears the buffer
function OctoBuffer:clear()
  -- clear buffer
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})

  -- delete extmarks
  local extmarks = vim.api.nvim_buf_get_extmarks(self.bufnr, constants.OCTO_COMMENT_NS, 0, -1, {})
  for _, m in ipairs(extmarks) do
    vim.api.nvim_buf_del_extmark(self.bufnr, constants.OCTO_COMMENT_NS, m[1])
  end
end

---Writes a repo to the buffer
function OctoBuffer:render_repo()
  self:clear()
  local node = self.node
  ---@cast node Repository
  writers.write_repo(self.bufnr, node)

  -- drop undo history
  utils.clear_history(self.bufnr)

  -- reset modified option
  vim.api.nvim_set_option_value("modified", false, { buf = self.bufnr })

  self.ready = true
end

---Writes an issue or pull request to the buffer.
function OctoBuffer:render_issue()
  self:clear()
  local node = self.node
  ---@cast node Issue|PullRequestWithReviewThreads

  -- write title
  writers.write_title(self.bufnr, node.title, 1)

  -- write details in buffer
  writers.write_details(self.bufnr, node)

  -- write issue/pr status
  writers.write_state(self.bufnr, node.state:upper(), self.number)

  -- write body
  writers.write_body(self.bufnr, node)

  -- write body reactions
  local reaction_line
  if utils.count_reactions(node.reactionGroups) > 0 then
    local line = vim.api.nvim_buf_line_count(self.bufnr) + 1
    writers.write_block(self.bufnr, { "", "" }, line)
    reaction_line = writers.write_reactions(self.bufnr, node.reactionGroups, line)
  end
  self.bodyMetadata.reactionGroups = node.reactionGroups
  self.bodyMetadata.reactionLine = reaction_line

  -- write timeline items
  ---@type LabeledEvent[]
  local unrendered_labeled_events = {}
  ---@type UnlabeledEvent[]
  local unrendered_unlabeled_events = {}
  local prev_is_event = false

  ---@type (IssueTimelineItems|PullRequestTimelineItems)[]
  local timeline_nodes = {}
  for _, item in ipairs(node.timelineItems.nodes) do
    if item ~= vim.NIL then
      table.insert(timeline_nodes, item)
    end
  end

  for _, item in ipairs(timeline_nodes) do
    if item.__typename ~= "LabeledEvent" and #unrendered_labeled_events > 0 then
      writers.write_labeled_events(self.bufnr, unrendered_labeled_events, "added")
      unrendered_labeled_events = {}
      prev_is_event = true
    end
    if item.__typename ~= "UnlabeledEvent" and #unrendered_unlabeled_events > 0 then
      writers.write_labeled_events(self.bufnr, unrendered_unlabeled_events, "removed")
      unrendered_unlabeled_events = {}
      prev_is_event = true
    end

    if item.__typename == "IssueComment" then
      ---@cast item IssueCommentWithTypename
      if prev_is_event then
        writers.write_block(self.bufnr, { "" })
      end

      -- write the comment
      local start_line, end_line = writers.write_comment(self.bufnr, item, "IssueComment")
      folds.create(self.bufnr, start_line + 1, end_line, true)
      prev_is_event = false
    elseif item.__typename == "PullRequestReview" then
      ---@cast item PullRequestReviewWithTypename
      if prev_is_event then
        writers.write_block(self.bufnr, { "" })
      end

      -- A review can have 0+ threads
      ---@type PullRequestReviewThread[]
      local threads = {}
      for _, comment in ipairs(item.comments.nodes) do
        for _, reviewThread in ipairs(node.reviewThreads.nodes) do
          if comment.id == reviewThread.comments.nodes[1].id then
            -- found a thread for the current review
            table.insert(threads, reviewThread)
          end
        end
      end

      -- skip reviews with no threads and empty body
      if #threads > 0 or not utils.is_blank(item.body) then
        -- print review header and top level comment
        local review_start, review_end = writers.write_comment(self.bufnr, item, "PullRequestReview")

        -- print threads
        if #threads > 0 then
          review_end = writers.write_threads(self.bufnr, threads)
          folds.create(self.bufnr, review_start + 1, review_end, true)
        end
        writers.write_block(self.bufnr, { "" })
        prev_is_event = false
      end
    elseif item.__typename == "AssignedEvent" then
      ---@cast item AssignedEvent
      writers.write_assigned_event(self.bufnr, item)
      prev_is_event = true
    elseif item.__typename == "PullRequestCommit" then
      ---@cast item PullRequestCommit
      writers.write_commit_event(self.bufnr, item)
      prev_is_event = true
    elseif item.__typename == "MergedEvent" then
      ---@cast item MergedEvent
      writers.write_merged_event(self.bufnr, item)
      prev_is_event = true
    elseif item.__typename == "ClosedEvent" then
      ---@cast item ClosedEvent
      writers.write_closed_event(self.bufnr, item)
      prev_is_event = true
    elseif item.__typename == "ReopenedEvent" then
      ---@cast item ReopenedEvent
      writers.write_reopened_event(self.bufnr, item)
      prev_is_event = true
    elseif item.__typename == "LabeledEvent" then
      ---@cast item LabeledEvent
      table.insert(unrendered_labeled_events, item)
    elseif item.__typename == "UnlabeledEvent" then
      ---@cast item UnlabeledEvent
      table.insert(unrendered_unlabeled_events, item)
    elseif item.__typename == "ReviewRequestedEvent" then
      ---@cast item ReviewRequestedEvent
      writers.write_review_requested_event(self.bufnr, item)
      prev_is_event = true
    elseif item.__typename == "ReviewRequestRemovedEvent" then
      ---@cast item ReviewRequestedRemovedEvent
      writers.write_review_request_removed_event(self.bufnr, item)
      prev_is_event = true
    elseif item.__typename == "ReviewDismissedEvent" then
      ---@cast item ReviewDismissedEvent
      writers.write_review_dismissed_event(self.bufnr, item)
      prev_is_event = true
    end
  end
  if prev_is_event then
    writers.write_block(self.bufnr, { "" })
  end

  -- drop undo history
  utils.clear_history(self.bufnr)

  -- reset modified option
  vim.api.nvim_set_option_value("modified", false, { buf = self.bufnr })

  self.ready = true
end

---Draws review threads
---@param threads PullRequestReviewThread[]
function OctoBuffer:render_threads(threads)
  self:clear()
  writers.write_threads(self.bufnr, threads)

  -- drop undo history
  utils.clear_history(self.bufnr)

  vim.api.nvim_set_option_value("modified", false, { buf = self.bufnr })
  self.ready = true
end

---Confgiures the buffer
function OctoBuffer:configure()
  -- configure buffer
  vim.api.nvim_buf_call(self.bufnr, function()
    vim.cmd [[setlocal filetype=octo]]
    vim.cmd [[setlocal buftype=acwrite]]
    vim.cmd [[setlocal omnifunc=v:lua.octo_omnifunc]]
    vim.cmd [[setlocal conceallevel=2]]
    vim.cmd [[setlocal nonumber norelativenumber nocursorline wrap]]

    if config.values.ui.use_signcolumn then
      vim.cmd [[setlocal signcolumn=yes]]
      autocmds.update_signs(self.bufnr)
    end
    if config.values.ui.use_statuscolumn then
      vim.opt_local.statuscolumn = [[%!v:lua.require'octo.ui.statuscolumn'.statuscolumn()]]
      autocmds.update_signs(self.bufnr)
    end
    if config.values.ui.use_foldtext then
      vim.opt_local.foldtext = [[v:lua.require'octo.folds'.foldtext()]]
    end
  end)

  self:apply_mappings()
end

---@class GithubContributor
---@field login string?
---@field id integer?
---@field node_id string?
---@field avatar_url string?
---@field gravatar_id string|nil?
---@field url string?
---@field html_url string?
---@field followers_url string?
---@field following_url string?
---@field gists_url string?
---@field starred_url string?
---@field subscriptions_url string?
---@field organizations_url string?
---@field repos_url string?
---@field events_url string?
---@field received_events_url string?
---@field type string
---@field site_admin boolean?
---@field contributions integer
---@field email string?
---@field name string?

---Accumulates all the taggable users into a single list that
--gets set as a buffer variable `taggable_users`. If this list of users
---is needed syncronously, this function will need to be refactored.
---The list of taggable users should contain:
--  - The PR author
--  - The authors of all the existing comments
--  - The contributors of the repo
function OctoBuffer:async_fetch_taggable_users()
  local users = self.taggable_users or {}

  -- add participants
  for _, p in pairs(self.node.participants.nodes) do
    table.insert(users, p.login)
  end

  -- add comment authors
  for _, c in pairs(self.commentsMetadata) do
    table.insert(users, c.author)
  end

  -- add repo contributors
  gh.run {
    args = { "api", string.format("repos/%s/contributors", self.repo) },
    cb = function(response)
      if not utils.is_blank(response) then
        ---@type GithubContributor[]
        local resp = vim.fn.json_decode(response)
        for _, contributor in ipairs(resp) do
          table.insert(users, contributor.login)
        end
        self.taggable_users = users
      end
    end,
  }
end

---@class GithubIssue
---@field id integer
---@field node_id string
---@field url string
---@field repository_url string
---@field labels_url string
---@field comments_url string
---@field events_url string
---@field html_url string
---@field number integer
---@field state string
---@field state_reason "completed"|"reopened"|"not_planned"|nil
---@field title string
---@field body string

---Fetches the issues in the repo so they can be used for completion.
function OctoBuffer:async_fetch_issues()
  gh.run {
    args = { "api", string.format("repos/%s/issues", self.repo) },
    cb = function(response)
      ---@type { number: integer, title: string }[]
      local issues_metadata = {}
      ---@type GithubIssue[]
      local resp = vim.fn.json_decode(response)
      for _, issue in ipairs(resp) do
        table.insert(issues_metadata, { number = issue.number, title = issue.title })
      end
      octo_repo_issues[self.repo] = issues_metadata
    end,
  }
end

---Syncs all the comments/title/body with GitHub
function OctoBuffer:save()
  local bufnr = vim.api.nvim_get_current_buf()

  -- collect comment metadata
  self:update_metadata()

  -- title & body
  if self.kind == "issue" or self.kind == "pull" then
    self:do_save_title_and_body()
  end

  -- comments
  for _, comment_metadata in ipairs(self.commentsMetadata) do
    if comment_metadata.body ~= comment_metadata.savedBody then
      if comment_metadata.id == nil then
        -- we use -1 as an indicator for new comments for which we dont currently have a GH id
        if comment_metadata.kind == "IssueComment" then
          self:do_add_issue_comment(comment_metadata)
        elseif comment_metadata.kind == "PullRequestReviewComment" then
          if not utils.is_blank(comment_metadata.replyTo) then
            -- comment is a reply to a thread comment
            self:do_add_thread_comment(comment_metadata)
          else
            -- comment starts a new thread of comments
            self:do_add_new_thread(comment_metadata)
          end
        elseif comment_metadata.kind == "PullRequestComment" then
          self:do_add_pull_request_comment(comment_metadata)
        end
      else
        -- comment is an existing comment
        self:do_update_comment(comment_metadata)
      end
    end
  end

  -- drop undo history
  utils.clear_history(self.bufnr)

  -- reset modified option
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
end

---Sync issue/PR title and body with GitHub
function OctoBuffer:do_save_title_and_body()
  local title_metadata = self.titleMetadata
  local desc_metadata = self.bodyMetadata
  local id = self.node.id
  if title_metadata.dirty or desc_metadata.dirty then
    -- trust but verify
    if string.find(title_metadata.body, "\n") then
      vim.api.nvim_err_writeln "Title can't contains new lines"
      return
    elseif title_metadata.body == "" then
      vim.api.nvim_err_writeln "Title can't be blank"
      return
    end

    local query
    if self:isIssue() then
      query = graphql("update_issue_mutation", id, title_metadata.body, desc_metadata.body)
    elseif self:isPullRequest() then
      query = graphql("update_pull_request_mutation", id, title_metadata.body, desc_metadata.body)
    end
    gh.run {
      args = { "api", "graphql", "-f", string.format("query=%s", query) },
      cb = function(output, stderr)
        if stderr and not utils.is_blank(stderr) then
          vim.api.nvim_err_writeln(stderr)
        elseif output then
          ---@type UpdateIssueMutationResponse|UpdatePullRequestMutationResponse
          local resp = vim.fn.json_decode(output)
          local obj
          if self:isPullRequest() then
            ---@cast resp UpdatePullRequestMutationResponse
            obj = resp.data.updatePullRequest.pullRequest
          elseif self:isIssue() then
            ---@cast resp UpdateIssueMutationResponse
            obj = resp.data.updateIssue.issue
          end
          if title_metadata.body == obj.title then
            title_metadata.savedBody = obj.title
            title_metadata.dirty = false
            self.titleMetadata = title_metadata
          end

          if desc_metadata.body == obj.body then
            desc_metadata.savedBody = obj.body
            desc_metadata.dirty = false
            self.bodyMetadata = desc_metadata
          end

          self:render_signs()
          utils.info "Saved!"
        end
      end,
    }
  end
end

---Add a new comment to the issue/PR
---@param comment_metadata CommentMetadata
function OctoBuffer:do_add_issue_comment(comment_metadata)
  -- create new issue comment
  local id = self.node.id
  local add_query = graphql("add_issue_comment_mutation", id, comment_metadata.body)
  gh.run {
    args = { "api", "graphql", "-f", string.format("query=%s", add_query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        vim.api.nvim_err_writeln(stderr)
      elseif output then
        ---@type AddIssueCommentMutationResponse
        local resp = vim.fn.json_decode(output)
        local respBody = resp.data.addComment.commentEdge.node.body
        local respId = resp.data.addComment.commentEdge.node.id
        if utils.trim(comment_metadata.body) == utils.trim(respBody) then
          comment_metadata.id = respId
          comment_metadata.savedBody = respBody
          comment_metadata.dirty = false
          self:render_signs()
        end
      end
    end,
  }
end

---@param comment_metadata CommentMetadata
function OctoBuffer:_update_thread_metadata(comment_metadata)
  -- update thread map
  local thread_id = comment_metadata.threadMetadata.threadId
  ---@type integer|nil
  local mark_id = nil
  for markId, threadMetadata in pairs(self.threadsMetadata) do
    if threadMetadata.threadId == thread_id then
      mark_id = tonumber(markId)
    end
  end
  if mark_id then
    local extmark = vim.api.nvim_buf_get_extmark_by_id(
      self.bufnr,
      constants.OCTO_THREAD_NS,
      mark_id,
      { details = true }
    )
    local thread_start = extmark[1]
    -- update extmark
    vim.api.nvim_buf_del_extmark(self.bufnr, constants.OCTO_THREAD_NS, mark_id)
    local thread_mark_id = vim.api.nvim_buf_set_extmark(self.bufnr, constants.OCTO_THREAD_NS, thread_start, 0, {
      end_line = comment_metadata.endLine + 2,
      end_col = 0,
    })
    self.threadsMetadata[tostring(thread_mark_id)] = self.threadsMetadata[tostring(mark_id)]
    self.threadsMetadata[tostring(mark_id)] = nil
  end
end

---Replies to a review comment thread
---@param comment_metadata CommentMetadata
function OctoBuffer:do_add_thread_comment(comment_metadata)
  -- create new thread reply
  local query = graphql(
    "add_pull_request_review_comment_mutation",
    comment_metadata.replyTo.id,
    comment_metadata.body,
    comment_metadata.reviewId
  )
  gh.run {
    args = { "api", "graphql", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        vim.api.nvim_err_writeln(stderr)
      elseif output then
        ---@type AddPullRequestReviewCommentMutationResponse
        local resp = vim.fn.json_decode(output)
        local resp_comment = resp.data.addPullRequestReviewComment.comment
        local comment_end
        if utils.trim(comment_metadata.body) == utils.trim(resp_comment.body) then
          comment_metadata.id = resp_comment.id
          comment_metadata.savedBody = resp_comment.body
          comment_metadata.dirty = false
          comment_end = comment_metadata.endLine

          local threads = resp_comment.pullRequest.reviewThreads.nodes
          local review = require("octo.reviews").get_current_review()
          if review then
            review:update_threads(threads)
          end

          self:render_signs()

          self:_update_thread_metadata(comment_metadata)
        end
      end
    end,
  }
end

---Adds a new review comment thread to the current review.
---@param comment_metadata CommentMetadata
function OctoBuffer:do_add_new_thread(comment_metadata)
  --TODO: How to create a new thread on a line where there is already one

  local review = require("octo.reviews").get_current_review()
  if review == nil then
    return
  end
  local layout = review.layout
  local pr = review.pull_request
  local file = layout:cur_file()
  if not file then
    utils.error "No file selected"
    return
  end
  local review_level = review:get_level()
  local isMultiline = true
  if comment_metadata.snippetStartLine == comment_metadata.snippetEndLine then
    isMultiline = false
  end

  -- create new thread
  if review_level == "PR" then
    local query
    if isMultiline then
      query = graphql(
        "add_pull_request_review_multiline_thread_mutation",
        comment_metadata.reviewId,
        comment_metadata.body,
        comment_metadata.path,
        comment_metadata.diffSide,
        comment_metadata.diffSide,
        comment_metadata.snippetStartLine,
        comment_metadata.snippetEndLine
      )
    else
      query = graphql(
        "add_pull_request_review_thread_mutation",
        comment_metadata.reviewId,
        comment_metadata.body,
        comment_metadata.path,
        comment_metadata.subjectType,
        comment_metadata.diffSide,
        comment_metadata.snippetStartLine
      )
    end
    gh.run {
      args = { "api", "graphql", "-f", string.format("query=%s", query) },
      cb = function(output, stderr)
        if stderr and not utils.is_blank(stderr) then
          vim.api.nvim_err_writeln(stderr)
        elseif output then
          ---@type AddPullRequestReviewThreadMutationResponse
          local resp = vim.fn.json_decode(output)
          local obj = resp.data.addPullRequestReviewThread
          if not utils.is_blank(obj.thread) then
            local new_comment = obj.thread.comments.nodes[1]
            if utils.trim(comment_metadata.body) == utils.trim(new_comment.body) then
              comment_metadata.id = new_comment.id
              comment_metadata.savedBody = new_comment.body
              comment_metadata.dirty = false
              local threads = obj.thread.pullRequest.reviewThreads.nodes
              if review then
                review:update_threads(threads)
              end
              self:render_signs()
            end
            comment_metadata.threadMetadata.threadId = obj.thread.id
            comment_metadata.threadMetadata.replyTo = obj.thread.comments.nodes[1].id
          else
            utils.error "Failed to create thread"
            return
          end
        end
      end,
    }
  elseif review_level == "COMMIT" then
    if isMultiline then
      utils.error "Can't create a multiline comment at the commit level"
      return
    else
      -- get the line number the comment is on
      local line
      ---@type ThreadMetadata[]
      local thread_metadatas = vim.tbl_values(self.threadsMetadata)
      for _, thread in ipairs(thread_metadatas) do
        if thread.threadId == nil then
          line = thread.line
        end
      end

      -- we need to convert the line number to a diff line number (position)
      local position = line
      if file.status ~= "A" then
        -- for non-added files (modified), check we are in a valid comment range
        local diffhunks = {}
        local diffhunk = ""
        local left_comment_ranges, right_comment_ranges = {}, {}
        if not utils.is_blank(pr.diff) then
          local diffhunks_map = utils.extract_diffhunks_from_diff(pr.diff)
          local file_diffhunks = diffhunks_map[comment_metadata.path]
          diffhunks, left_comment_ranges, right_comment_ranges = utils.process_patch(file_diffhunks)
        end
        local comment_ranges
        if comment_metadata.diffSide == "RIGHT" then
          comment_ranges = right_comment_ranges
        elseif comment_metadata.diffSide == "LEFT" then
          comment_ranges = left_comment_ranges
        end
        local idx, offset = 0, 0
        for i, range in ipairs(comment_ranges) do
          if range[1] <= line and range[2] >= line then
            diffhunk = diffhunks[i]
            idx = i
            break
          end
        end
        for i, hunk in ipairs(diffhunks) do
          if i < idx then
            offset = offset + #vim.split(hunk, "\n")
          end
        end
        if not vim.startswith(diffhunk, "@@") then
          diffhunk = "@@ " .. diffhunk
        end

        local map = utils.generate_line2position_map(diffhunk)
        if comment_metadata.diffSide == "RIGHT" then
          position = map.right_side_lines[tostring(line)]
        elseif comment_metadata.diffSide == "LEFT" then
          position = map.left_side_lines[tostring(line)]
        end
        position = position + offset - 1
      end

      local query = graphql(
        "add_pull_request_review_commit_thread_mutation",
        layout.right.commit,
        comment_metadata.body,
        comment_metadata.reviewId,
        comment_metadata.path,
        position
      )
      gh.run {
        args = { "api", "graphql", "-f", string.format("query=%s", query) },
        cb = function(output, stderr)
          if stderr and not utils.is_blank(stderr) then
            vim.api.nvim_err_writeln(stderr)
          elseif output then
            ---@type AddPullRequestReviewCommitThreadMutationResponse
            local r = vim.fn.json_decode(output)
            local resp = r.data.addPullRequestReviewComment
            if not utils.is_blank(resp.comment) then
              if utils.trim(comment_metadata.body) == utils.trim(resp.comment.body) then
                comment_metadata.id = resp.comment.id
                comment_metadata.savedBody = resp.comment.body
                comment_metadata.dirty = false
                if review then
                  local threads = resp.comment.pullRequest.reviewThreads.nodes
                  review:update_threads(threads)
                end
                self:render_signs()
              end
            else
              utils.error "Failed to create thread"
              return
            end
          end
        end,
      }
    end
  end
end

---@class GithubReply
---@field node_id string
---@field body string

---Replies a review thread w/o creating a new review
---@param comment_metadata CommentMetadata
function OctoBuffer:do_add_pull_request_comment(comment_metadata)
  local current_review = require("octo.reviews").get_current_review()
  if not utils.is_blank(current_review) then
    utils.error "Please submit or discard the current review before adding a comment"
    return
  end
  gh.run {
    args = {
      "api",
      "--method",
      "POST",
      string.format("/repos/%s/pulls/%d/comments/%s/replies", self.repo, self.number, comment_metadata.replyToRest),
      "-f",
      string.format([[body=%s]], utils.escape_char(comment_metadata.body)),
      "--jq",
      ".",
    },
    headers = { "Accept: application/vnd.github.v3+json" },
    cb = function(output, stderr)
      if not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        ---@type GithubReply
        local resp = vim.fn.json_decode(output)
        if not utils.is_blank(resp) then
          if utils.trim(comment_metadata.body) == utils.trim(resp.body) then
            comment_metadata.id = resp.node_id
            comment_metadata.savedBody = resp.body
            comment_metadata.dirty = false
            self:render_signs()

            self:_update_thread_metadata(comment_metadata)
          end
        else
          utils.error "Failed to create thread"
          return
        end
      end
    end,
  }
end

---Update a comment's metadata
---@param comment_metadata CommentMetadata
function OctoBuffer:do_update_comment(comment_metadata)
  -- update comment/reply
  local update_query
  if comment_metadata.kind == "IssueComment" then
    update_query = graphql("update_issue_comment_mutation", comment_metadata.id, comment_metadata.body)
  elseif comment_metadata.kind == "PullRequestReviewComment" or comment_metadata.kind == "PullRequestComment" then
    update_query = graphql("update_pull_request_review_comment_mutation", comment_metadata.id, comment_metadata.body)
  elseif comment_metadata.kind == "PullRequestReview" then
    update_query = graphql("update_pull_request_review_mutation", comment_metadata.id, comment_metadata.body)
  end
  gh.run {
    args = { "api", "graphql", "-f", string.format("query=%s", update_query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        vim.api.nvim_err_writeln(stderr)
      elseif output then
        ---@type UpdateIssueCommentMutationResponse|UpdatePullRequestReviewCommentMutationResponse|UpdatePullRequestReviewMutationResponse
        local resp = vim.fn.json_decode(output)
        local resp_comment
        if comment_metadata.kind == "IssueComment" then
          resp_comment = resp.data.updateIssueComment.issueComment
        elseif comment_metadata.kind == "PullRequestReviewComment" or comment_metadata.kind == "PullRequestComment" then
          resp_comment = resp.data.updatePullRequestReviewComment.pullRequestReviewComment
          local threads =
            resp.data.updatePullRequestReviewComment.pullRequestReviewComment.pullRequest.reviewThreads.nodes
          local review = require("octo.reviews").get_current_review()
          if review then
            review:update_threads(threads)
          end
        elseif comment_metadata.kind == "PullRequestReview" then
          resp_comment = resp.data.updatePullRequestReview.pullRequestReview
        end
        if resp_comment and utils.trim(comment_metadata.body) == utils.trim(resp_comment.body) then
          comment_metadata.savedBody = comment_metadata.body
          comment_metadata.dirty = false
          self:render_signs()
        end
      end
    end,
  }
end

---Update the buffer metadata
function OctoBuffer:update_metadata()
  if not self.ready then
    return
  end
  ---@type (TitleMetadata|BodyMetadata|CommentMetadata)[]
  local metadata_objs = {}
  if self.kind == "issue" or self.kind == "pull" then
    table.insert(metadata_objs, self.titleMetadata)
    table.insert(metadata_objs, self.bodyMetadata)
  end
  for _, m in ipairs(self.commentsMetadata) do
    table.insert(metadata_objs, m)
  end

  for _, metadata in ipairs(metadata_objs) do
    local mark =
      vim.api.nvim_buf_get_extmark_by_id(self.bufnr, constants.OCTO_COMMENT_NS, metadata.extmark, { details = true })
    local start_line, end_line = utils.get_extmark_region(mark)
    -- Indexing is zero-based, end-exclusive, so adding 1 to end line
    local status, lines = pcall(vim.api.nvim_buf_get_lines, self.bufnr, start_line, end_line + 1, true)
    if status and lines then
      local text = vim.fn.join(lines, "\n")
      metadata.body = text
      metadata.dirty = utils.trim(metadata.body) ~= utils.trim(metadata.savedBody) and true or false
    end
    metadata.startLine = start_line
    metadata.endLine = end_line
  end
end

---Renders the signs in the signcolumn or statuscolumn
function OctoBuffer:render_signs()
  local use_signcolumn = config.values.ui.use_signcolumn
  local use_statuscolumn = config.values.ui.use_statuscolumn
  if not self.ready or (not use_statuscolumn and not use_signcolumn) then
    return
  end

  local issue_dirty = false

  -- update comment metadata (lines, etc.)
  self:update_metadata()

  -- clear all signs
  signs.unplace(self.bufnr)

  -- clear virtual texts
  vim.api.nvim_buf_clear_namespace(self.bufnr, constants.OCTO_EMPTY_MSG_VT_NS, 0, -1)

  local metadata
  if self.kind == "issue" or self.kind == "pull" then
    -- title
    metadata = self.titleMetadata
    if metadata then
      if metadata.dirty then
        issue_dirty = true
      end
      signs.place_signs(self.bufnr, metadata.startLine, metadata.endLine, metadata.dirty)
    end

    -- description
    metadata = self.bodyMetadata
    if metadata then
      if metadata.dirty then
        issue_dirty = true
      end
      signs.place_signs(self.bufnr, metadata.startLine, metadata.endLine, metadata.dirty)

      -- description virtual text
      if utils.is_blank(metadata.body) then
        local desc_vt = { { constants.NO_BODY_MSG, "OctoEmpty" } }
        writers.write_virtual_text(self.bufnr, constants.OCTO_EMPTY_MSG_VT_NS, metadata.startLine, desc_vt)
      end
    end
  end

  -- comments
  local comments_metadata = self.commentsMetadata
  for _, comment_metadata in ipairs(comments_metadata) do
    metadata = comment_metadata
    if metadata then
      if metadata.dirty then
        issue_dirty = true
      end
      signs.place_signs(self.bufnr, metadata.startLine, metadata.endLine, metadata.dirty)

      -- comment virtual text
      if utils.is_blank(metadata.body) then
        local comment_vt = { { constants.NO_BODY_MSG, "OctoEmpty" } }
        writers.write_virtual_text(self.bufnr, constants.OCTO_EMPTY_MSG_VT_NS, metadata.startLine, comment_vt)
      end
    end
  end

  -- reset modified option
  if not issue_dirty then
    vim.api.nvim_set_option_value("modified", false, { buf = self.bufnr })
  end
end

--- Checks if the buffer represents a review comment thread
---@return boolean
function OctoBuffer:isReviewThread()
  return self.kind == "reviewthread"
end

--- Checks if the buffer represents a Pull Request
---@return boolean
function OctoBuffer:isPullRequest()
  return self.kind == "pull"
end

--- Checks if the buffer represents an Issue
---@return boolean
function OctoBuffer:isIssue()
  return self.kind == "issue"
end

---Checks if the buffer represents a GitHub repo
---@return boolean
function OctoBuffer:isRepo()
  return self.kind == "repo"
end

---Gets the PR object for the current octo buffer
---@return OctoPullRequest?
function OctoBuffer:get_pr()
  if not self:isPullRequest() then
    utils.error "Not in a PR buffer"
    return
  end

  local Rev = require("octo.reviews.rev").Rev
  local PullRequest = require("octo.model.pull-request").PullRequest
  local bufnr = vim.api.nvim_get_current_buf()
  return PullRequest:new {
    bufnr = bufnr,
    repo = self.repo,
    number = self.number,
    id = self.node.id,
    left = Rev:new(self.node.baseRefOid),
    right = Rev:new(self.node.headRefOid),
    files = self.node.files.nodes,
  }
end

--- Get a issue/PR comment at cursor (if any)
---@return CommentMetadata?
function OctoBuffer:get_comment_at_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return self:get_comment_at_line(cursor[1])
end

--- Get a issue/PR comment at a given line (if any)
---@param line integer
---@return CommentMetadata?
function OctoBuffer:get_comment_at_line(line)
  for _, comment in ipairs(self.commentsMetadata) do
    local mark =
      vim.api.nvim_buf_get_extmark_by_id(self.bufnr, constants.OCTO_COMMENT_NS, comment.extmark, { details = true })
    local start_line = mark[1] + 1
    local end_line = mark[3]["end_row"] + 1
    if start_line + 1 <= line and end_line - 2 >= line then
      comment.bufferStartLine = start_line
      comment.bufferEndLine = end_line
      return comment
    end
  end
end

---Gets the issue/PR body at cursor (if any)
---@return BodyMetadata?
---@return integer?
---@return integer?
function OctoBuffer:get_body_at_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local metadata = self.bodyMetadata
  local mark =
    vim.api.nvim_buf_get_extmark_by_id(self.bufnr, constants.OCTO_COMMENT_NS, metadata.extmark, { details = true })
  local start_line = mark[1] + 1
  local end_line = mark[3]["end_row"] + 1
  if start_line + 1 <= cursor[1] and end_line - 2 >= cursor[1] then
    return metadata, start_line, end_line
  end
end

---Gets the review thread at cursor (if any)
---@return ThreadMetadata?
function OctoBuffer:get_thread_at_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return self:get_thread_at_line(cursor[1])
end

---Gets the review thread at a given line (if any)
---@param line integer
---@return ThreadMetadata?
function OctoBuffer:get_thread_at_line(line)
  local thread_marks = vim.api.nvim_buf_get_extmarks(self.bufnr, constants.OCTO_THREAD_NS, 0, -1, { details = true })
  for _, mark in ipairs(thread_marks) do
    local thread = self.threadsMetadata[tostring(mark[1])]
    if thread then
      local startLine = mark[2] + 1
      local endLine = mark[4].end_row
      if startLine <= line and endLine >= line then
        thread.bufferStartLine = startLine
        thread.bufferEndLine = endLine
        return thread
      end
    end
  end
end

---Gets the reactions groups at cursor (if any)
---@return string?
function OctoBuffer:get_reactions_at_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local body_reaction_line = self.bodyMetadata.reactionLine
  if body_reaction_line and body_reaction_line == cursor[1] then
    return self.node.id
  end

  local comments_metadata = self.commentsMetadata
  if comments_metadata then
    for _, c in pairs(comments_metadata) do
      if c.reactionLine and c.reactionLine == cursor[1] then
        return c.id
      end
    end
  end
end

---Updates the reactions groups at cursor (if any)
---@param reaction_groups ReactionGroup[]
---@param reaction_line integer
function OctoBuffer:update_reactions_at_cursor(reaction_groups, reaction_line)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local reactions_count = 0
  for _, group in ipairs(reaction_groups) do
    if group.users.totalCount > 0 then
      reactions_count = reactions_count + 1
    end
  end

  local comments = self.commentsMetadata
  for i, comment in ipairs(comments) do
    local mark =
      vim.api.nvim_buf_get_extmark_by_id(self.bufnr, constants.OCTO_COMMENT_NS, comment.extmark, { details = true })
    local start_line = mark[1] + 1
    local end_line = mark[3].end_row + 1
    if start_line <= cursor[1] and end_line >= cursor[1] then
      -- cursor located in the body of a comment
      -- update reaction groups
      comments[i].reactionGroups = reaction_groups

      -- update reaction line
      if not comments[i].reactionLine and reactions_count > 0 then
        comments[i].reactionLine = reaction_line
      elseif reactions_count == 0 then
        comments[i].reactionLine = nil
      end
      return
    end
  end

  -- cursor not located at any comment, so updating issue
  --  update reaction groups
  self.bodyMetadata.reactionGroups = reaction_groups
  local body_reaction_line = self.bodyMetadata.reactionLine
  if not body_reaction_line and reactions_count > 0 then
    self.bodyMetadata.reactionLine = reaction_line
  elseif reactions_count == 0 then
    self.bodyMetadata.reactionLine = nil
  end
end

return M
