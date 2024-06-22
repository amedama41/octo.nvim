local entry_display = require "telescope.pickers.entry_display"
local bubbles = require "octo.ui.bubbles"
local utils = require "octo.utils"

local M = {}

---@class IssueEntry
---@field filename string
---@field kind "issue"|"pull_request"
---@field value integer
---@field ordinal string
---@field display fun(entry: IssueEntry)
---@field obj BriefIssue|BriefPullRequest
---@field repo string

---@param max_number integer
---@param print_repo boolean?
---@return fun(obj: BriefIssue|BriefPullRequest?): IssueEntry?
function M.gen_from_issue(max_number, print_repo)
  ---@param entry IssueEntry
  local make_display = function(entry)
    if not entry then
      return nil
    end

    local layout, columns
    if print_repo then
      columns = {
        { entry.value, "TelescopeResultsNumber" },
        { entry.repo, "OctoDetailsLabel" },
        { entry.obj.title },
      }
      layout = {
        separator = " ",
        items = {
          { width = max_number },
          { width = 35 },
          { remaining = true },
        },
      }
    else
      local icon = entry.kind == "issue" and " " or " "
      columns = {
        { entry.value, "TelescopeResultsNumber" },
        { icon .. " " .. entry.obj.title },
      }
      layout = {
        separator = " ",
        items = {
          { width = max_number },
          { remaining = true },
        },
      }
    end

    local displayer = entry_display.create(layout)

    return displayer(columns)
  end

  return function(obj)
    if not obj or vim.tbl_isempty(obj) then
      return nil
    end
    local kind = obj.__typename == "Issue" and "issue" or "pull_request"
    local filename
    if kind == "issue" then
      filename = utils.get_issue_uri(obj.repository.nameWithOwner, obj.number)
    else
      filename = utils.get_pull_request_uri(obj.repository.nameWithOwner, obj.number)
    end
    return {
      filename = filename,
      kind = kind,
      value = obj.number,
      ordinal = obj.number .. " " .. obj.title,
      display = make_display,
      obj = obj,
      repo = obj.repository.nameWithOwner,
    }
  end
end

---@class GitCommitEntry
---@field value string
---@field parent string
---@field ordinal string
---@field msg string
---@field display fun(entry: GitCommitEntry)
---@field author string
---@field date string

---@return fun(entry: GithubPullRequestCommit?): GitCommitEntry?
function M.gen_from_git_commits()
  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 8 },
      { remaining = true },
    },
  }

  ---@param entry GitCommitEntry
  local make_display = function(entry)
    return displayer {
      { entry.value:sub(1, 7), "TelescopeResultsNumber" },
      vim.split(entry.msg, "\n")[1],
    }
  end

  return function(entry)
    if not entry then
      return nil
    end

    return {
      value = entry.sha,
      parent = entry.parents[1].sha,
      ordinal = entry.sha .. " " .. entry.commit.message,
      msg = entry.commit.message,
      display = make_display,
      author = string.format("%s <%s>", entry.commit.author.name, entry.commit.author.email),
      date = entry.commit.author.date,
    }
  end
end

---@class GitChangedFile
---@field value string
---@field ordinal string
---@field msg string
---@field display fun(entry: GitChangedFile)
---@field change GithubDiffEntry

---@return fun(entry: GithubDiffEntry?): GitChangedFile?
function M.gen_from_git_changed_files()
  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 8 },
      { width = string.len "modified" },
      { width = 5 },
      { width = 5 },
      { remaining = true },
    },
  }

  ---@param entry GitChangedFile
  local make_display = function(entry)
    return displayer {
      { entry.value:sub(1, 7), "TelescopeResultsNumber" },
      { entry.change.status, "OctoDetailsLabel" },
      { string.format("+%d", entry.change.additions), "OctoPullAdditions" },
      { string.format("-%d", entry.change.deletions), "OctoPullDeletions" },
      vim.split(entry.msg, "\n")[1],
    }
  end

  return function(entry)
    if not entry then
      return nil
    end

    return {
      value = entry.sha,
      ordinal = entry.sha .. " " .. entry.filename,
      msg = entry.filename,
      display = make_display,
      change = entry,
    }
  end
end

---@class ReviewThreadEntry
---@field value string
---@field ordinal string
---@field display fun(entry: ReviewThreadEntry)
---@field thread PullRequestReviewThread

---@return fun(thread: PullRequestReviewThread?): ReviewThreadEntry?
function M.gen_from_review_thread(linenr_length)
  ---@param entry ReviewThreadEntry
  local make_display = function(entry)
    if not entry then
      return nil
    end

    local columns = {
      { entry.thread.path, "TelescopeResultsNumber" },
      { entry.thread.diffSide },
      { entry.thread.startLine },
      { entry.thread.line },
    }

    local displayer = entry_display.create {
      separator = " ",
      items = {
        { remaining = true },
        { width = 5 },
        { width = linenr_length },
        { width = linenr_length },
      },
    }
    return displayer(columns)
  end

  return function(thread)
    if not thread or vim.tbl_isempty(thread) then
      return nil
    end

    return {
      value = thread.path .. ":" .. thread.startLine .. ":" .. thread.line,
      ordinal = thread.path .. ":" .. thread.startLine .. ":" .. thread.line,
      display = make_display,
      thread = thread,
    }
  end
end

---@class ProjectEntry
---@field value string
---@field ordinal string
---@field display fun(entry: ProjectEntry)
---@field project Project

---@return fun(project: Project?): ProjectEntry?
function M.gen_from_project()
  ---@param entry ProjectEntry
  local make_display = function(entry)
    if not entry then
      return nil
    end

    local columns = {
      { entry.project.name },
    }

    local displayer = entry_display.create {
      separator = " ",
      items = {
        { remaining = true },
      },
    }

    return displayer(columns)
  end

  return function(project)
    if not project or vim.tbl_isempty(project) then
      return nil
    end

    return {
      value = project.id,
      ordinal = project.id .. " " .. project.name,
      display = make_display,
      project = project,
    }
  end
end

---@class ProjectColumnEntry
---@field value string
---@field ordinal string
---@field display fun(entry: ProjectColumnEntry)
---@field column ProjectColumn

---@return fun(column: ProjectColumn?): ProjectColumnEntry?
function M.gen_from_project_column()
  ---@param entry ProjectColumnEntry
  local make_display = function(entry)
    if not entry then
      return nil
    end

    local columns = {
      { entry.column.name },
    }

    local displayer = entry_display.create {
      separator = " ",
      items = {
        { remaining = true },
      },
    }

    return displayer(columns)
  end

  return function(column)
    if not column or vim.tbl_isempty(column) then
      return nil
    end
    return {
      value = column.id,
      ordinal = column.id .. " " .. column.name,
      display = make_display,
      column = column,
    }
  end
end

---@class ProjectCardEntry
---@field value string
---@field ordinal string
---@field display fun(entry: ProjectCardEntry)
---@field card ProjectCard

---@return fun(card: ProjectCard?): ProjectCardEntry?
function M.gen_from_project_card()
  ---@param entry ProjectCardEntry
  local make_display = function(entry)
    if not entry then
      return nil
    end

    local columns = {
      { entry.card.column.name },
      { string.format(" (%s)", entry.card.project.name), "OctoDetailsValue" },
    }

    local displayer = entry_display.create {
      separator = " ",
      items = {
        { width = 5 },
        { remaining = true },
      },
    }

    return displayer(columns)
  end

  return function(card)
    if not card or vim.tbl_isempty(card) then
      return nil
    end

    return {
      value = card.id,
      ordinal = card.project.name .. " " .. card.column.name,
      display = make_display,
      card = card,
    }
  end
end

---@class LabelEntry
---@field value string
---@field ordinal string
---@field display fun(entry: LabelEntry)
---@field label LabelWithId

---@return fun(label: LabelWithId?): LabelEntry?
function M.gen_from_label()
  ---@param entry LabelEntry
  local make_display = function(entry)
    if not entry then
      return nil
    end

    local columns = bubbles.make_label_bubble(entry.label.name, entry.label.color)

    local displayer = entry_display.create {
      separator = "",
      items = {
        { width = 1 },
        { remaining = true },
        { width = 1 },
      },
    }

    return displayer(columns)
  end

  return function(label)
    if not label or vim.tbl_isempty(label) then
      return nil
    end

    return {
      value = label.id,
      ordinal = label.name,
      display = make_display,
      label = label,
    }
  end
end

---@class TeamEntry
---@field value string
---@field ordinal string
---@field display fun(entry: TeamEntry)
---@field team { id: string, name: string }

---@return fun(team: { id: string, name: string }?): TeamEntry?
function M.gen_from_team()
  ---@param entry TeamEntry
  local make_display = function(entry)
    if not entry then
      return nil
    end

    local columns = {
      { entry.team.name },
    }

    local displayer = entry_display.create {
      separator = "",
      items = {
        { remaining = true },
      },
    }

    return displayer(columns)
  end

  return function(team)
    if not team or vim.tbl_isempty(team) then
      return nil
    end

    return {
      value = team.id,
      ordinal = team.name,
      display = make_display,
      team = team,
    }
  end
end

---@class UserEntry
---@field value string
---@field ordinal string
---@field display fun(entry: UserEntry)
---@field user { id: string, login: string, teams: Team[]? }

---@return fun(user: { id: string, login: string, teams: Team[]? }?): UserEntry?
function M.gen_from_user()
  ---@param entry UserEntry
  local make_display = function(entry)
    if not entry then
      return nil
    end

    local columns = {
      { entry.user.login },
    }

    local displayer = entry_display.create {
      separator = "",
      items = {
        { remaining = true },
      },
    }

    return displayer(columns)
  end

  return function(user)
    if not user or vim.tbl_isempty(user) then
      return nil
    end

    return {
      value = user.id,
      ordinal = user.login,
      display = make_display,
      user = user,
    }
  end
end

---@class RepoEntry
---@field filename string
---@field kind "repo"
---@field value string
---@field ordinal string
---@field display fun(entry: RepoEntry)
---@field repo RepositoryBase

---@param max_nameWithOwner integer
---@param max_forkCount integer
---@param max_stargazerCount integer
---@return fun(repo: RepositoryBase?): RepoEntry?
function M.gen_from_repo(max_nameWithOwner, max_forkCount, max_stargazerCount)
  ---@param entry RepoEntry
  local make_display = function(entry)
    if not entry then
      return nil
    end

    local fork_str = ""
    if entry.repo.isFork then
      fork_str = "fork"
    end

    local access_str = "public"
    if entry.repo.isPrivate then
      access_str = "private"
    end

    local columns = {
      { string.sub(entry.repo.nameWithOwner, 1, 50), "TelescopeResultsNumber" },
      { "s:", "TelescopeResultsNumber" },
      { entry.repo.stargazerCount },
      { "f:", "TelescopeResultsNumber" },
      { entry.repo.forkCount },
      { access_str },
      { fork_str },
      { entry.repo.description },
    }

    local displayer = entry_display.create {
      separator = " ",
      items = {
        { width = math.min(max_nameWithOwner, 50) },
        { width = 2 },
        { width = max_stargazerCount },
        { width = 2 },
        { width = max_forkCount },
        { width = vim.fn.len "private" },
        { width = vim.fn.len "fork" },
        { remaining = true },
      },
    }

    return displayer(columns)
  end

  return function(repo)
    if not repo or vim.tbl_isempty(repo) then
      return nil
    end

    if repo.description == vim.NIL then
      repo.description = ""
    end

    return {
      filename = utils.get_repo_uri(_, repo),
      kind = "repo",
      value = repo.nameWithOwner,
      ordinal = repo.nameWithOwner .. " " .. repo.description,
      display = make_display,
      repo = repo,
    }
  end
end

---@class GistEntry
---@field value string
---@field ordinal string
---@field display fun(entry: GistEntry)
---@field gist Gist

---@return fun(gist: Gist?): GistEntry?
function M.gen_from_gist()
  ---@param entry GistEntry
  local make_display = function(entry)
    if not entry then
      return
    end

    local fork_str = ""
    if entry.gist.isFork then
      fork_str = "fork"
    end

    local access_str = "private"
    if entry.gist.isPublic then
      access_str = "public"
    end

    local description = entry.gist.description
    if (not description or utils.is_blank(description) or description == vim.NIL) and #entry.gist.files > 0 then
      description = entry.gist.files[1].name
    end

    local columns = {
      { access_str },
      { fork_str },
      { description, "TelescopeResultsNumber" },
    }

    local displayer = entry_display.create {
      separator = " ",
      items = {
        { width = vim.fn.len "private" },
        { width = vim.fn.len "fork" },
        { remaining = true },
      },
    }

    return displayer(columns)
  end

  return function(gist)
    if not gist or vim.tbl_isempty(gist) then
      return
    end

    if gist.description == vim.NIL then
      gist.description = ""
    end

    return {
      value = gist.name,
      ordinal = gist.name .. " " .. gist.description,
      display = make_display,
      gist = gist,
    }
  end
end

---@class OctoActionEntry
---@field value string
---@field ordinal string
---@field display fun(entry: OctoActionEntry)
---@field action { object: string, name: string, fun: function }

---@return fun(action: { object: string, name: string, fun: function }?): OctoActionEntry?
function M.gen_from_octo_actions()
  ---@param entry OctoActionEntry
  local make_display = function(entry)
    if not entry then
      return nil
    end

    local columns = {
      { entry.action.object, "TelescopeResultsNumber" },
      { entry.action.name },
    }

    local displayer = entry_display.create {
      separator = "",
      items = {
        { width = 12 },
        { remaining = true },
      },
    }

    return displayer(columns)
  end

  return function(action)
    if not action or vim.tbl_isempty(action) then
      return nil
    end

    return {
      value = action.name,
      ordinal = action.object .. " " .. action.name,
      display = make_display,
      action = action,
    }
  end
end

---@class IssueTemplateEntry
---@field value string
---@field ordinal string
---@field display fun(entry: IssueTemplateEntry)
---@field template IssueTemplate

---@return fun(template: IssueTemplate?): IssueTemplateEntry?
function M.gen_from_issue_templates()
  ---@param entry IssueTemplateEntry
  local make_display = function(entry)
    if not entry then
      return nil
    end

    local columns = {
      { entry.template.name, "TelescopeResultsNumber" },
      { entry.template.about },
    }

    local displayer = entry_display.create {
      separator = "",
      items = {
        { width = 25 },
        { remaining = true },
      },
    }

    return displayer(columns)
  end

  return function(template)
    if not template or vim.tbl_isempty(template) then
      return nil
    end

    return {
      value = template.name,
      ordinal = template.name .. " " .. template.about,
      display = make_display,
      template = template,
    }
  end
end

return M
