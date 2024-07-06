local gh = require "octo.gh"
local graphql = require "octo.gh.graphql"
local navigation = require "octo.navigation"
local previewers = require "octo.pickers.telescope.previewers"
local entry_maker = require "octo.pickers.telescope.entry_maker"
local reviews = require "octo.reviews"
local utils = require "octo.utils"
local octo_config = require "octo.config"

local actions = require "telescope.actions"
local action_set = require "telescope.actions.set"
local action_state = require "telescope.actions.state"
local conf = require("telescope.config").values
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"

local M = {}

function M.not_implemented()
  utils.error "Not implemented yet"
end

local dropdown_opts = require("telescope.themes").get_dropdown {
  layout_config = {
    width = 0.4,
    height = 15,
  },
  prompt_title = false,
  results_title = false,
  previewer = false,
}

---@param opts table<string, string>
---@param kind "issue"|"pull_request"
local function get_filter(opts, kind)
  local filter = ""
  local allowed_values = {}
  if kind == "issue" then
    allowed_values = { "since", "createdBy", "assignee", "mentioned", "labels", "milestone", "states" }
  elseif kind == "pull_request" then
    allowed_values = { "baseRefName", "headRefName", "labels", "states" }
  end

  for _, value in pairs(allowed_values) do
    if opts[value] then
      local val
      if #vim.split(opts[value], ",") > 1 then
        -- list
        val = vim.split(opts[value], ",")
      else
        -- string
        val = opts[value]
      end
      val = vim.fn.json_encode(val)
      val = string.gsub(val, '"OPEN"', "OPEN")
      val = string.gsub(val, '"CLOSED"', "CLOSED")
      val = string.gsub(val, '"MERGED"', "MERGED")
      filter = filter .. value .. ":" .. val .. ","
    end
  end

  return filter
end

---@param command "default"|"horizontal"|"vertical"|"tab"
local function open(command)
  return function(prompt_bufnr)
    ---@type IssueEntry|RepoEntry
    local selection = action_state.get_selected_entry(prompt_bufnr)
    actions.close(prompt_bufnr)
    if command == "default" then
      vim.cmd [[:buffer %]]
    elseif command == "horizontal" then
      vim.cmd [[:sbuffer %]]
    elseif command == "vertical" then
      vim.cmd [[:vert sbuffer %]]
    elseif command == "tab" then
      vim.cmd [[:tab sb %]]
    end
    utils.get(selection.kind, selection.repo, selection.value)
  end
end

---@param command "default"|"horizontal"|"vertical"|"tab"
---@return fun(prompt_bufnr: integer)
local function open_preview_buffer(command)
  return function(prompt_bufnr)
    actions.close(prompt_bufnr)
    local preview_bufnr = require("telescope.state").get_global_key "last_preview_bufnr"
    if command == "default" then
      vim.cmd(string.format(":buffer %d", preview_bufnr))
    elseif command == "horizontal" then
      vim.cmd(string.format(":sbuffer %d", preview_bufnr))
    elseif command == "vertical" then
      vim.cmd(string.format(":vert sbuffer %d", preview_bufnr))
    elseif command == "tab" then
      vim.cmd(string.format(":tab sb %d", preview_bufnr))
    end

    vim.cmd [[stopinsert]]
  end
end

---@return fun(prompt_bufnr: integer)
local function open_in_browser()
  return function(prompt_bufnr)
    ---@type IssueEntry|RepoEntry
    local entry = action_state.get_selected_entry(prompt_bufnr)
    local number
    local repo = entry.repo
    if entry.kind ~= "repo" then
      ---@cast entry IssueEntry
      number = entry.value
    end
    actions.close(prompt_bufnr)
    navigation.open_in_browser(entry.kind, repo, number)
  end
end

local function copy_url()
  return function(prompt_bufnr)
    local entry = action_state.get_selected_entry(prompt_bufnr)
    local url = entry.obj.url
    vim.fn.setreg("+", url, "c")
    utils.info("Copied '" .. url .. "' to the system clipboard (+ register)")
  end
end

--
-- ISSUES
--
---@param opts table<string, any>
function M.issues(opts)
  opts = opts or {}
  if not opts.states then
    opts.states = "OPEN"
  end
  local filter = get_filter(opts, "issue")
  if utils.is_blank(opts.repo) then
    opts.repo = utils.get_remote_name()
  end
  if not opts.repo then
    utils.error "Cannot find repo"
    return
  end

  local owner, name = utils.split_repo(opts.repo)
  local cfg = octo_config.values
  local order_by = cfg.issues.order_by
  local query = graphql("issues_query", owner, name, filter, order_by.field, order_by.direction, { escape = false })
  utils.info "Fetching issues (this may take a while) ..."
  gh.run {
    args = { "api", "graphql", "--paginate", "--jq", ".", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        ---@type IssuesQueryResponse
        local resp = utils.aggregate_pages(output, "data.repository.issues.nodes")
        local issues = resp.data.repository.issues.nodes
        if #issues == 0 then
          utils.error(string.format("There are no matching issues in %s.", opts.repo))
          return
        end
        local max_number = -1
        for _, issue in ipairs(issues) do
          if #tostring(issue.number) > max_number then
            max_number = #tostring(issue.number)
          end
        end
        opts.preview_title = opts.preview_title or ""
        opts.prompt_title = opts.prompt_title or ""
        opts.results_title = opts.results_title or ""
        pickers
          .new(opts, {
            finder = finders.new_table {
              results = issues,
              entry_maker = entry_maker.gen_from_issue(max_number),
            },
            sorter = conf.generic_sorter(opts),
            previewer = previewers.issue.new(opts),
            attach_mappings = function(_, map)
              action_set.select:replace(function(prompt_bufnr, type)
                open(type)(prompt_bufnr)
              end)
              map("i", cfg.picker_config.mappings.open_in_browser.lhs, open_in_browser())
              map("i", cfg.picker_config.mappings.copy_url.lhs, copy_url())
              return true
            end,
          })
          :find()
      end
    end,
  }
end

--
-- GISTS
--
---@param prompt_bufnr integer
local function open_gist(prompt_bufnr)
  local selection = action_state.get_selected_entry(prompt_bufnr)
  local gist = selection.gist
  actions.close(prompt_bufnr)
  for _, file in ipairs(gist.files) do
    local bufnr = vim.api.nvim_create_buf(true, true)
    if file.text then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(file.text, "\n"))
    else
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, gist.description)
    end
    vim.api.nvim_buf_set_name(bufnr, file.name)
    vim.api.nvim_win_set_buf(0, bufnr)
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd [[filetype detect]]
    end)
  end
end

---@param opts table<string, any>
function M.gists(opts)
  local privacy
  if opts.public then
    privacy = "PUBLIC"
  elseif opts.secret then
    privacy = "SECRET"
  else
    privacy = "ALL"
  end
  local query = graphql("gists_query", privacy)
  gh.run {
    args = { "api", "graphql", "--paginate", "--jq", ".", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        ---@type GistsQueryResponse
        local resp = utils.aggregate_pages(output, "data.viewer.gists.nodes")
        local gists = resp.data.viewer.gists.nodes
        opts.preview_title = opts.preview_title or ""
        opts.prompt_title = opts.prompt_title or ""
        opts.results_title = opts.results_title or ""
        pickers
          .new(opts, {
            finder = finders.new_table {
              results = gists,
              entry_maker = entry_maker.gen_from_gist(),
            },
            previewer = previewers.gist.new(opts),
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(_, map)
              map("i", "<CR>", open_gist)
              return true
            end,
          })
          :find()
      end
    end,
  }
end

--
-- PULL REQUESTS
--

---@return fun(prompt_bufnr: integer)
local function checkout_pull_request()
  return function(prompt_bufnr)
    local sel = action_state.get_selected_entry(prompt_bufnr)
    actions.close(prompt_bufnr)
    utils.checkout_pr(sel.obj.number)
  end
end

---@return fun(prompt_bufnr: integer)
local function merge_pull_request()
  return function(prompt_bufnr)
    local sel = action_state.get_selected_entry(prompt_bufnr)
    actions.close(prompt_bufnr)
    utils.merge_pr(sel.obj.number)
  end
end

---@param opts table<string, any>
function M.pull_requests(opts)
  opts = opts or {}
  if not opts.states then
    opts.states = "OPEN"
  end
  local filter = get_filter(opts, "pull_request")
  if utils.is_blank(opts.repo) then
    opts.repo = utils.get_remote_name()
  end
  if not opts.repo then
    utils.error "Cannot find repo"
    return
  end

  local owner, name = utils.split_repo(opts.repo)
  local cfg = octo_config.values
  local order_by = cfg.pull_requests.order_by
  local query =
    graphql("pull_requests_query", owner, name, filter, order_by.field, order_by.direction, { escape = false })
  utils.info "Fetching pull requests (this may take a while) ..."
  gh.run {
    args = { "api", "graphql", "--paginate", "--jq", ".", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        ---@type PullRequestsQueryResponse
        local resp = utils.aggregate_pages(output, "data.repository.pullRequests.nodes")
        local pull_requests = resp.data.repository.pullRequests.nodes
        if #pull_requests == 0 then
          utils.error(string.format("There are no matching pull requests in %s.", opts.repo))
          return
        end
        local max_number = -1
        for _, pull in ipairs(pull_requests) do
          if #tostring(pull.number) > max_number then
            max_number = #tostring(pull.number)
          end
        end
        opts.preview_title = opts.preview_title or ""
        opts.prompt_title = opts.prompt_title or ""
        opts.results_title = opts.results_title or ""
        pickers
          .new(opts, {
            finder = finders.new_table {
              results = pull_requests,
              entry_maker = entry_maker.gen_from_issue(max_number),
            },
            sorter = conf.generic_sorter(opts),
            previewer = previewers.issue.new(opts),
            attach_mappings = function(_, map)
              action_set.select:replace(function(prompt_bufnr, type)
                open(type)(prompt_bufnr)
              end)
              map("i", cfg.picker_config.mappings.checkout_pr.lhs, checkout_pull_request())
              map("i", cfg.picker_config.mappings.open_in_browser.lhs, open_in_browser())
              map("i", cfg.picker_config.mappings.copy_url.lhs, copy_url())
              map("i", cfg.picker_config.mappings.merge_pr.lhs, merge_pull_request())
              return true
            end,
          })
          :find()
      end
    end,
  }
end

---@class GithubPullRequestCommit
---@field url string
---@field sha string
---@field node_id string
---@field html_url string
---@field comments_url string
---@field commit { url: string, author: { name: string, email: string, date: string }?, commiter: { name: string, email: string, date: string }?, message: string, comment_count: integer, tree: { sha: string, url: string }, verification: { verified: boolean, reason: string, payload: string?, signature: string? }? }
---@field authoer any
---@field committer any
---@field parents { sha: string, url: string, html_url: string? }[]
---@field stats { additions: integer, deletions: integer, total: integer }?
---@field files { sha: string, filename: string, status: string, additions: integer, deletions: integer, changes: integer, blob_url: string, raw_url: string, contents_url: string, patch: string, previous_filename: string }[]?

--
-- COMMITS
--
function M.commits()
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if not buffer or not buffer:isPullRequest() then
    return
  end
  -- TODO: graphql
  local url = string.format("repos/%s/pulls/%d/commits", buffer.repo, buffer.number)
  gh.run {
    args = { "api", "--paginate", url },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        ---@type GithubPullRequestCommit[]
        local results = vim.fn.json_decode(output)
        pickers
          .new({}, {
            prompt_title = false,
            results_title = false,
            preview_title = false,
            finder = finders.new_table {
              results = results,
              entry_maker = entry_maker.gen_from_git_commits(),
            },
            sorter = conf.generic_sorter {},
            previewer = previewers.commit.new { repo = buffer.repo },
            attach_mappings = function()
              action_set.select:replace(function(prompt_bufnr, type)
                open_preview_buffer(type)(prompt_bufnr)
              end)
              return true
            end,
          })
          :find()
      end
    end,
  }
end

---@param callback fun(right: string, left: string)
function M.review_commits(callback)
  local current_review = require("octo.reviews").get_current_review()
  if not current_review then
    utils.error "No review in progress"
    return
  end
  -- TODO: graphql
  local url =
    string.format("repos/%s/pulls/%d/commits", current_review.pull_request.repo, current_review.pull_request.number)
  gh.run {
    args = { "api", "--paginate", url },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        ---@type GithubPullRequestCommit[]
        local results = vim.fn.json_decode(output)

        -- add a fake entry to represent the entire pull request
        table.insert(results, {
          sha = current_review.pull_request.right.commit,
          commit = {
            message = "[[ENTIRE PULL REQUEST]]",
            author = {
              name = "",
              email = "",
              date = "",
            },
          },
          parents = {
            {
              sha = current_review.pull_request.left.commit,
            },
          },
        })

        pickers
          .new({}, {
            prompt_title = false,
            results_title = false,
            preview_title = false,
            finder = finders.new_table {
              results = results,
              entry_maker = entry_maker.gen_from_git_commits(),
            },
            sorter = conf.generic_sorter {},
            previewer = previewers.commit.new { repo = current_review.pull_request.repo },
            attach_mappings = function()
              action_set.select:replace(function(prompt_bufnr)
                ---@type GitCommitEntry
                local commit = action_state.get_selected_entry(prompt_bufnr)
                local right = commit.value
                local left = commit.parent
                actions.close(prompt_bufnr)
                callback(right, left)
              end)
              return true
            end,
          })
          :find()
      end
    end,
  }
end

---@class GithubDiffEntry
---@field sha string
---@field filename string
---@field status GithubDiffEntryStatus
---@field additions integer
---@field deletions integer
---@field changes integer
---@field blob_url string
---@field raw_url string
---@field contents_url string
---@field patch string?
---@field previous_filename string?

--
-- FILES
--
function M.changed_files()
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if not buffer or not buffer:isPullRequest() then
    return
  end
  local url = string.format("repos/%s/pulls/%d/files", buffer.repo, buffer.number)
  gh.run {
    args = { "api", "--paginate", url },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        ---@type GithubDiffEntry[]
        local results = vim.fn.json_decode(output)
        pickers
          .new({}, {
            prompt_title = false,
            results_title = false,
            preview_title = false,
            finder = finders.new_table {
              results = results,
              entry_maker = entry_maker.gen_from_git_changed_files(),
            },
            sorter = conf.generic_sorter {},
            previewer = previewers.changed_files.new { repo = buffer.repo, number = buffer.number },
            attach_mappings = function()
              action_set.select:replace(function(prompt_bufnr, type)
                open_preview_buffer(type)(prompt_bufnr)
              end)
              return true
            end,
          })
          :find()
      end
    end,
  }
end

---
-- SEARCH
---
---@param opts table<string, any>
function M.search(opts)
  opts = opts or {}
  local cfg = octo_config.values
  local requester = function()
    ---@param prompt string
    ---@return (BriefIssue|BriefPullRequest)[]
    return function(prompt)
      if not opts.prompt and utils.is_blank(prompt) then
        return {}
      end
      if type(opts.prompt) == "string" then
        opts.prompt = { opts.prompt }
      end
      local results = {}
      for _, val in ipairs(opts.prompt) do
        local _prompt = prompt
        if val then
          _prompt = string.format("%s %s", val, _prompt)
        end
        local query = graphql("search_query", _prompt)
        local output = gh.run {
          args = { "api", "graphql", "-f", string.format("query=%s", query) },
          mode = "sync",
        }
        if output then
          ---@type SearchQueryResponse
          local resp = vim.fn.json_decode(output)
          for _, issue in ipairs(resp.data.search.nodes) do
            table.insert(results, issue)
          end
        end
      end
      return results
    end
  end
  local finder = finders.new_dynamic {
    fn = requester(),
    entry_maker = entry_maker.gen_from_issue(6),
  }
  if opts.static then
    local results = requester() ""
    finder = finders.new_table {
      results = results,
      entry_maker = entry_maker.gen_from_issue(6, true),
    }
  end
  opts.preview_title = opts.preview_title or ""
  opts.prompt_title = opts.prompt_title or ""
  opts.results_title = opts.results_title or ""
  pickers
    .new(opts, {
      finder = finder,
      sorter = conf.generic_sorter(opts),
      previewer = previewers.issue.new(opts),
      attach_mappings = function(_, map)
        action_set.select:replace(function(prompt_bufnr, type)
          open(type)(prompt_bufnr)
        end)
        map("i", cfg.picker_config.mappings.open_in_browser.lhs, open_in_browser())
        map("i", cfg.picker_config.mappings.copy_url.lhs, copy_url())
        return true
      end,
    })
    :find()
end

---
-- REVIEW COMMENTS
---
---@param threads PullRequestReviewThread[]
function M.pending_threads(threads)
  local max_linenr_length = -1
  for _, thread in ipairs(threads) do
    max_linenr_length = math.max(max_linenr_length, #tostring(thread.startLine))
    max_linenr_length = math.max(max_linenr_length, #tostring(thread.line))
  end
  pickers
    .new({}, {
      prompt_title = false,
      results_title = false,
      preview_title = false,
      finder = finders.new_table {
        results = threads,
        entry_maker = entry_maker.gen_from_review_thread(max_linenr_length),
      },
      sorter = conf.generic_sorter {},
      previewer = previewers.review_thread.new {},
      attach_mappings = function()
        actions.select_default:replace(function(prompt_bufnr)
          ---@type PullRequestReviewThread
          local thread = action_state.get_selected_entry(prompt_bufnr).thread
          actions.close(prompt_bufnr)
          reviews.jump_to_pending_review_thread(thread)
        end)
        return true
      end,
    })
    :find()
end

---
-- PROJECTS
---
---@param cb fun(id: string)
function M.select_project_card(cb)
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  local cards = buffer.node.projectCards
  if not cards or #cards.nodes == 0 then
    utils.error "Cant find any project cards"
    return
  end

  if #cards.nodes == 1 then
    cb(cards.nodes[1].id)
  else
    local opts = vim.deepcopy(dropdown_opts)
    pickers
      .new(opts, {
        finder = finders.new_table {
          results = cards.nodes,
          entry_maker = entry_maker.gen_from_project_card(),
        },
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(_, _)
          actions.select_default:replace(function(prompt_bufnr)
            ---@type ProjectCardEntry
            local source_card = action_state.get_selected_entry(prompt_bufnr)
            actions.close(prompt_bufnr)
            cb(source_card.card.id)
          end)
          return true
        end,
      })
      :find()
  end
end

---@param cb fun(id: string)
function M.select_target_project_column(cb)
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if not buffer then
    return
  end

  local query = graphql("projects_query", buffer.owner, buffer.name, vim.g.octo_viewer, buffer.owner)
  gh.run {
    args = { "api", "graphql", "--paginate", "-f", string.format("query=%s", query) },
    cb = function(output)
      if output then
        ---@type ProjectsQueryResponse
        local resp = vim.fn.json_decode(output)
        local projects = {}
        local user_projects = resp.data.user and resp.data.user.projects.nodes or {}
        local repo_projects = resp.data.repository and resp.data.repository.projects.nodes or {}
        local org_projects = not resp.errors and resp.data.organization.projects.nodes or {}
        vim.list_extend(projects, repo_projects)
        vim.list_extend(projects, user_projects)
        vim.list_extend(projects, org_projects)
        if #projects == 0 then
          utils.error(string.format("There are no matching projects for %s.", buffer.repo))
          return
        end

        local opts = vim.deepcopy(dropdown_opts)
        pickers
          .new(opts, {
            finder = finders.new_table {
              results = projects,
              entry_maker = entry_maker.gen_from_project(),
            },
            sorter = conf.generic_sorter(opts),
            attach_mappings = function()
              action_set.select:replace(function(prompt_bufnr)
                ---@type ProjectEntry
                local selected_project = action_state.get_selected_entry(prompt_bufnr)
                actions._close(prompt_bufnr, true)
                local opts2 = vim.deepcopy(dropdown_opts)
                pickers
                  .new(opts2, {
                    finder = finders.new_table {
                      results = selected_project.project.columns.nodes,
                      entry_maker = entry_maker.gen_from_project_column(),
                    },
                    sorter = conf.generic_sorter(opts2),
                    attach_mappings = function()
                      action_set.select:replace(function(prompt_bufnr2)
                        ---@type ProjectColumnEntry
                        local selected_column = action_state.get_selected_entry(prompt_bufnr2)
                        actions.close(prompt_bufnr2)
                        cb(selected_column.column.id)
                      end)
                      return true
                    end,
                  })
                  :find()
              end)
              return true
            end,
          })
          :find()
      end
    end,
  }
end

--
-- LABELS
--
---@param cb fun(id: string)
function M.select_label(cb)
  local opts = vim.deepcopy(dropdown_opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if not buffer then
    return
  end

  local query = graphql("labels_query", buffer.owner, buffer.name)
  gh.run {
    args = { "api", "graphql", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        ---@type LabelsQeuryResponse
        local resp = vim.fn.json_decode(output)
        local labels = resp.data.repository.labels.nodes
        pickers
          .new(opts, {
            finder = finders.new_table {
              results = labels,
              entry_maker = entry_maker.gen_from_label(),
            },
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(_, _)
              actions.select_default:replace(function(prompt_bufnr)
                ---@type LabelEntry
                local selected_label = action_state.get_selected_entry(prompt_bufnr)
                actions.close(prompt_bufnr)
                cb(selected_label.label.id)
              end)
              return true
            end,
          })
          :find()
      end
    end,
  }
end

---@param cb fun(id)
function M.select_assigned_label(cb)
  local opts = vim.deepcopy(dropdown_opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if not buffer then
    return
  end
  local query, key
  if buffer:isIssue() then
    query = graphql("issue_labels_query", buffer.owner, buffer.name, buffer.number)
    key = "issue"
  elseif buffer:isPullRequest() then
    query = graphql("pull_request_labels_query", buffer.owner, buffer.name, buffer.number)
    key = "pullRequest"
  end
  gh.run {
    args = { "api", "graphql", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        ---@type LabelsQeuryResponse
        local resp = vim.fn.json_decode(output)
        local labels = resp.data.repository[key].labels.nodes
        pickers
          .new(opts, {
            finder = finders.new_table {
              results = labels,
              entry_maker = entry_maker.gen_from_label(),
            },
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(_, _)
              actions.select_default:replace(function(prompt_bufnr)
                ---@type LabelEntry
                local selected_label = action_state.get_selected_entry(prompt_bufnr)
                actions.close(prompt_bufnr)
                cb(selected_label.label.id)
              end)
              return true
            end,
          })
          :find()
      end
    end,
  }
end

--
-- ASSIGNEES
--
---@param owner string
---@param repository string
---@param cb fun(id: string)
function M.select_user(owner, repository, cb)
  local opts = vim.deepcopy(dropdown_opts)
  opts.layout_config = {
    width = 0.4,
    height = 15,
  }

  local function make_command_list()
    local query = graphql("users_query", owner, repository)
    local command, args = gh.make_command({
      args = {
        "api", "graphql",
        "--paginate",
        "-f", string.format("query=%s", query),
        "--jq", ".data.repository.assignableUsers.nodes.[]",
      },
    })
    local command_list = { command }
    vim.list_extend(command_list, args)
    return command_list
  end
  local function make_entry_marker()
    local from_user = entry_maker.gen_from_user()
    return function(line)
      ---@type { id: string, login: string, teams: Team? }
      local user = vim.fn.json_decode(line)
      return from_user(user)
    end
  end

  pickers
    .new(opts, {
      finder = finders.new_oneshot_job(make_command_list(), {
        entry_maker = make_entry_marker(),
      }),
      sorter = sorters.get_fuzzy_file(opts),
      attach_mappings = function()
        actions.select_default:replace(function(prompt_bufnr)
          ---@type UserEntry
          local selected_user = action_state.get_selected_entry(prompt_bufnr)
          actions._close(prompt_bufnr, true)
          if not selected_user.teams then
            -- user
            cb(selected_user.value)
          else
            -- organization, pick a team
            pickers
              .new(opts, {
                prompt_title = false,
                results_title = false,
                preview_title = false,
                finder = finders.new_table {
                  results = selected_user.teams,
                  entry_maker = entry_maker.gen_from_team(),
                },
                sorter = conf.generic_sorter(opts),
                attach_mappings = function()
                  actions.select_default:replace(function(prompt_bufnr)
                    ---@type TeamEntry
                    local selected_team = action_state.get_selected_entry(prompt_bufnr)
                    actions.close(prompt_bufnr)
                    cb(selected_team.team.id)
                  end)
                  return true
                end,
              })
              :find()
          end
        end)
        return true
      end,
    })
    :find()
end

--
-- ASSIGNEES
--
---@param cb fun(user_id: string)
function M.select_assignee(cb)
  local opts = vim.deepcopy(dropdown_opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if not buffer then
    return
  end
  local query, key
  if buffer:isIssue() then
    query = graphql("issue_assignees_query", buffer.owner, buffer.name, buffer.number)
    key = "issue"
  elseif buffer:isPullRequest() then
    query = graphql("pull_request_assignees_query", buffer.owner, buffer.name, buffer.number)
    key = "pullRequest"
  end
  gh.run {
    args = { "api", "graphql", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        ---@type IssueAssigneesQueryResponse|PullRequestAssigneesQueryResponse
        local resp = vim.fn.json_decode(output)
        ---@type User[]
        local assignees = resp.data.repository[key].assignees.nodes
        pickers
          .new(opts, {
            finder = finders.new_table {
              results = assignees,
              entry_maker = entry_maker.gen_from_user(),
            },
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(_, _)
              actions.select_default:replace(function(prompt_bufnr)
                ---@type UserEntry
                local selected_assignee = action_state.get_selected_entry(prompt_bufnr)
                actions.close(prompt_bufnr)
                cb(selected_assignee.user.id)
              end)
              return true
            end,
          })
          :find()
      end
    end,
  }
end

--
-- REPOS
--
---@param opts table<string, any>
function M.repos(opts)
  opts = opts or {}
  local cfg = octo_config.values
  if not opts.login then
    if vim.g.octo_viewer then
      opts.login = vim.g.octo_viewer
    else
      local remote_hostname = require("octo.utils").get_remote_host()
      opts.login = require("octo.gh").get_user_name(remote_hostname)
    end
  end
  local query = graphql("repos_query", opts.login)
  utils.info "Fetching repositories (this may take a while) ..."
  gh.run {
    args = { "api", "graphql", "--paginate", "--jq", ".", "-f", string.format("query=%s", query) },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        ---@type ReposQueryResponse
        local resp = utils.aggregate_pages(output, "data.repositoryOwner.repositories.nodes")
        local repos = resp.data.repositoryOwner.repositories.nodes
        if #repos == 0 then
          utils.error(string.format("There are no matching repositories for %s.", opts.login))
          return
        end
        local max_nameWithOwner = -1
        local max_forkCount = -1
        local max_stargazerCount = -1
        for _, repo in ipairs(repos) do
          max_nameWithOwner = math.max(max_nameWithOwner, #repo.nameWithOwner)
          max_forkCount = math.max(max_forkCount, #tostring(repo.forkCount))
          max_stargazerCount = math.max(max_stargazerCount, #tostring(repo.stargazerCount))
        end
        opts.preview_title = opts.preview_title or ""
        opts.prompt_title = opts.prompt_title or ""
        opts.results_title = opts.results_title or ""
        pickers
          .new(opts, {
            finder = finders.new_table {
              results = repos,
              entry_maker = entry_maker.gen_from_repo(max_nameWithOwner, max_forkCount, max_stargazerCount),
            },
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(_, map)
              action_set.select:replace(function(prompt_bufnr, type)
                open(type)(prompt_bufnr)
              end)
              map("i", cfg.picker_config.mappings.open_in_browser.lhs, open_in_browser())
              map("i", cfg.picker_config.mappings.copy_url.lhs, copy_url())
              return true
            end,
          })
          :find()
      end
    end,
  }
end

--
-- OCTO
--
---@param flattened_actions { object: string, name: string, fun: function }[]
function M.actions(flattened_actions)
  local opts = {
    preview_title = "",
    prompt_title = "",
    results_title = "",
  }

  pickers
    .new(opts, {
      finder = finders.new_table {
        results = flattened_actions,
        entry_maker = entry_maker.gen_from_octo_actions(),
      },
      sorter = conf.generic_sorter(opts),
      attach_mappings = function()
        actions.select_default:replace(function(prompt_bufnr)
          ---@type OctoActionEntry
          local selected_command = action_state.get_selected_entry(prompt_bufnr)
          actions.close(prompt_bufnr)
          selected_command.action.fun()
        end)
        return true
      end,
    })
    :find()
end

--
-- Issue templates
--
---@param templates IssueTemplate[]
---@param cb fun(template: IssueTemplate)
function M.issue_templates(templates, cb)
  local opts = {
    preview_title = "",
    prompt_title = "Issue templates",
    results_title = "",
  }

  pickers
    .new(opts, {
      finder = finders.new_table {
        results = templates,
        entry_maker = entry_maker.gen_from_issue_templates(),
      },
      sorter = conf.generic_sorter(opts),
      previewer = previewers.issue_template.new {},
      attach_mappings = function()
        actions.select_default:replace(function(prompt_bufnr)
          ---@type IssueTemplateEntry
          local selected_template = action_state.get_selected_entry(prompt_bufnr)
          actions.close(prompt_bufnr)
          cb(selected_template.template)
        end)
        return true
      end,
    })
    :find()
end

M.picker = {
  issues = M.issues,
  prs = M.pull_requests,
  gists = M.gists,
  commits = M.commits,
  review_commits = M.review_commits,
  changed_files = M.changed_files,
  pending_threads = M.pending_threads,
  project_cards = M.select_project_card,
  project_cards_v2 = M.not_implemented,
  project_columns = M.select_target_project_column,
  project_columns_v2 = M.not_implemented,
  labels = M.select_label,
  assigned_labels = M.select_assigned_label,
  users = M.select_user,
  assignees = M.select_assignee,
  repos = M.repos,
  search = M.search,
  actions = M.actions,
  issue_templates = M.issue_templates,
}

return M
