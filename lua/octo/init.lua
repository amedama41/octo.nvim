local OctoBuffer = require("octo.model.octo-buffer").OctoBuffer
local autocmds = require "octo.autocmds"
local config = require "octo.config"
local constants = require "octo.constants"
local commands = require "octo.commands"
local completion = require "octo.completion"
local folds = require "octo.folds"
local gh = require "octo.gh"
local graphql = require "octo.gh.graphql"
local picker = require "octo.picker"
local reviews = require "octo.reviews"
local signs = require "octo.ui.signs"
local window = require "octo.ui.window"
local writers = require "octo.ui.writers"
local utils = require "octo.utils"
local vim = vim

---@type table<string, { number: integer, title: string }[]>
_G.octo_repo_issues = {}
---@type table<integer, OctoBuffer>
_G.octo_buffers = {}
_G.octo_colors_loaded = false

local M = {}

function M.setup(user_config)
  if not vim.fn.has "nvim-0.7" then
    utils.error "octo.nvim requires neovim 0.7+"
    return
  end

  config.setup(user_config or {})
  if not vim.fn.executable(config.values.gh_cmd) then
    utils.error("gh executable not found using path: " .. config.values.gh_cmd)
    return
  end

  signs.setup()
  picker.setup()
  completion.setup()
  folds.setup()
  autocmds.setup()
  commands.setup()
  gh.setup()
end

---@param bufnr integer?
function M.configure_octo_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local split, path = utils.get_split_and_path(bufnr)
  local buffer = octo_buffers[bufnr]
  if split and path then
    -- review diff buffers
    local current_review = reviews.get_current_review()
    if current_review and #current_review.threads > 0 then
      current_review.layout:cur_file():place_signs()
    end
  elseif buffer then
    -- issue/pr/reviewthread buffers
    buffer:configure()
  end
end

function M.save_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  buffer:save()
end

---@param bufnr integer?
function M.load_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local bufname = vim.fn.bufname(bufnr)
  local repo, kind, number = string.match(bufname, "octo://(.+)/(.+)/(%d+)")
  if not repo then
    repo = string.match(bufname, "octo://(.+)/repo")
    if repo then
      kind = "repo"
    end
  end
  if (kind == "issue" or kind == "pull") and not repo and not number then
    vim.api.nvim_err_writeln("Incorrect buffer: " .. bufname)
    return
  elseif kind == "repo" and not repo then
    vim.api.nvim_err_writeln("Incorrect buffer: " .. bufname)
    return
  end
  M.load(repo, kind, number, function(obj)
    vim.api.nvim_buf_call(bufnr, function()
      M.create_buffer(kind, obj, repo, false)
    end)
  end)
end

---@param repo string
---@param kind "pull"|"issue"|"repo"
---@param number integer?
---@param cb fun(obj: PullRequest_|Issue|Repository)
function M.load(repo, kind, number, cb)
  local owner, name = utils.split_repo(repo)
  local query, key

  if kind == "pull" then
    query = graphql("pull_request_query", owner, name, number, _G.octo_pv2_fragment)
    key = "pullRequest"
  elseif kind == "issue" then
    query = graphql("issue_query", owner, name, number, _G.octo_pv2_fragment)
    key = "issue"
  elseif kind == "repo" then
    query = graphql("repository_query", owner, name)
  end
  gh.run {
    args = { "api", "graphql", "--paginate", "--jq", ".", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        vim.api.nvim_err_writeln(stderr)
      elseif output then
        if kind == "pull" or kind == "issue" then
          ---@type PullRequestQueryResponse|IssueQueryResponse
          local resp = utils.aggregate_pages(output, string.format("data.repository.%s.timelineItems.nodes", key))
          ---@type PullRequest_|Issue
          local obj = resp.data.repository[key]
          cb(obj)
        elseif kind == "repo" then
          ---@type RepositoryQueryResponse
          local resp = vim.fn.json_decode(output)
          local obj = resp.data.repository
          cb(obj)
        end
      end
    end,
  }
end

function M.render_signs()
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  buffer:render_signs()
end

function M.on_cursor_hold()
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if not buffer then
    return
  end

  -- reactions popup
  local id = buffer:get_reactions_at_cursor()
  if id then
    local query = graphql("reactions_for_object_query", id)
    gh.run {
      args = { "api", "graphql", "-f", string.format("query=%s", query) },
      cb = function(output, stderr)
        if stderr and not utils.is_blank(stderr) then
          vim.api.nvim_err_writeln(stderr)
        elseif output then
          ---@type ReactionsForObjectQueryResponse
          local resp = vim.fn.json_decode(output)
          ---@type table<ReactionContent, string[]>
          local reactions = {}
          local reactionGroups = resp.data.node.reactionGroups
          for _, reactionGroup in ipairs(reactionGroups) do
            local users = reactionGroup.users.nodes
            ---@type string[]
            local logins = {}
            for _, user in ipairs(users) do
              table.insert(logins, user.login)
            end
            if #logins > 0 then
              reactions[reactionGroup.content] = logins
            end
          end
          local popup_bufnr = vim.api.nvim_create_buf(false, true)
          local lines_count, max_length = writers.write_reactions_summary(popup_bufnr, reactions)
          window.create_popup {
            bufnr = popup_bufnr,
            width = 4 + max_length,
            height = 2 + lines_count,
          }
        end
      end,
    }
    return
  end

  -- user popup
  local login = utils.extract_pattern_at_cursor(constants.USER_PATTERN)
  if login then
    local query = graphql("user_profile_query", login)
    gh.run {
      args = { "api", "graphql", "-f", string.format("query=%s", query) },
      cb = function(output, stderr)
        if stderr and not utils.is_blank(stderr) then
          vim.api.nvim_err_writeln(stderr)
        elseif output then
          ---@type UserProfileQueryResponse
          local resp = vim.fn.json_decode(output)
          local user = resp.data.user
          local popup_bufnr = vim.api.nvim_create_buf(false, true)
          local lines, max_length = writers.write_user_profile(popup_bufnr, user)
          window.create_popup {
            bufnr = popup_bufnr,
            width = 4 + max_length,
            height = 2 + lines,
          }
        end
      end,
    }
    return
  end

  -- link popup
  local repo, number = utils.extract_issue_at_cursor(buffer.repo)
  if not repo or not number then
    return
  end
  local owner, name = utils.split_repo(repo)
  local query = graphql("issue_summary_query", owner, name, number)
  gh.run {
    args = { "api", "graphql", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        vim.api.nvim_err_writeln(stderr)
      elseif output then
        ---@type IssueSummaryQueryResponse
        local resp = vim.fn.json_decode(output)
        local issue = resp.data.repository.issueOrPullRequest
        local popup_bufnr = vim.api.nvim_create_buf(false, true)
        local max_length = 80
        local lines = writers.write_issue_summary(popup_bufnr, issue, { max_length = max_length })
        window.create_popup {
          bufnr = popup_bufnr,
          width = max_length,
          height = 2 + lines,
        }
      end
    end,
  }
end

---@param kind "pull"|"issue"|"repo"
---@param obj PullRequest_|Issue|Repository
---@param repo string
---@param create boolean
function M.create_buffer(kind, obj, repo, create)
  if not obj.id then
    utils.error("Cannot find " .. repo)
    return
  end

  local bufnr
  if create then
    bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(bufnr)
    vim.cmd(string.format("file octo://%s/%s/%d", repo, kind, obj.number))
  else
    bufnr = vim.api.nvim_get_current_buf()
  end

  local octo_buffer = OctoBuffer:new {
    bufnr = bufnr,
    number = obj.number,
    repo = repo,
    node = obj,
  }

  octo_buffer:configure()
  if kind == "repo" then
    octo_buffer:render_repo()
  else
    octo_buffer:render_issue()
    octo_buffer:async_fetch_taggable_users()
    octo_buffer:async_fetch_issues()
  end
end

return M
