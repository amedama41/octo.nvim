local utils = require "octo.utils"
local gh = require "octo.gh"

local M = {}

---@class OctoPullRequest
---@field repo string
---@field owner string
---@field name string
---@field number integer
---@field id string
---@field bufnr integer?
---@field left Rev
---@field right Rev
---@field local_right boolean
---@field local_left boolean
---@field files table<string, FileViewedState>
---@field diff string
local OctoPullRequest = {}
OctoPullRequest.__index = OctoPullRequest

---@class PullRequestOpts
---@field repo string
---@field number integer
---@field id string
---@field left Rev
---@field right Rev
---@field bufnr integer?
---@field files PullRequestChangedFile[]

---PullRequest constructor.
---@param opts PullRequestOpts
---@return OctoPullRequest
function OctoPullRequest:new(opts)
  local this = {
    -- TODO: rename to nwo
    repo = opts.repo,
    number = opts.number,
    owner = "",
    name = "",
    id = opts.id,
    left = opts.left,
    right = opts.right,
    local_right = false,
    local_left = false,
    bufnr = opts.bufnr,
    diff = "",
  }
  this.files = {}
  for _, file in ipairs(opts.files) do
    this.files[file.path] = file.viewerViewedState
  end
  this.owner, this.name = utils.split_repo(this.repo)
  utils.commit_exists(this.right.commit, function(exists)
    this.local_right = exists
  end)
  utils.commit_exists(this.left.commit, function(exists)
    this.local_left = exists
  end)

  setmetatable(this, self)

  self:get_diff(this)

  return this
end

M.PullRequest = OctoPullRequest

---@param left Rev
---@param right Rev
---@param files PullRequestChangedFile[]
function OctoPullRequest:update(left, right, files)
  self.left = left
  self.right = right
  utils.commit_exists(self.right.commit, function(exists)
    self.local_right = exists
  end)
  utils.commit_exists(self.left.commit, function(exists)
    self.local_left = exists
  end)
  self.files = {}
  for _, file in ipairs(files) do
    self.files[file.path] = file.viewerViewedState
  end
end

---Fetch the diff of the PR
---@param pr OctoPullRequest
function OctoPullRequest:get_diff(pr)
  local url = string.format("repos/%s/pulls/%d", pr.repo, pr.number)
  gh.run {
    args = { "api", "--paginate", url },
    headers = { "Accept: application/vnd.github.v3.diff" },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        pr.diff = output
      end
    end,
  }
end

---Fetch the changed files for a given PR
---@param callback fun(files: FileEntry[])
function OctoPullRequest:get_changed_files(callback)
  local url = string.format("repos/%s/pulls/%d/files", self.repo, self.number)
  gh.run {
    args = { "api", "--paginate", url, "--jq", "." },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        local FileEntry = require("octo.reviews.file-entry").FileEntry
        ---@type GithubDiffEntry[]
        local results = {}
        for _, line in ipairs(vim.split(output, "\n")) do
          vim.list_extend(results, vim.json.decode(line))
        end
        ---@type FileEntry[]
        local files = {}
        for _, result in ipairs(results) do
          local entry = FileEntry:new {
            path = result.filename,
            previous_path = result.previous_filename,
            patch = result.patch,
            pull_request = self,
            status = utils.file_status_map[result.status],
            stats = {
              additions = result.additions,
              deletions = result.deletions,
              changes = result.changes,
            },
          }
          table.insert(files, entry)
        end
        callback(files)
      end
    end,
  }
end

---@class GithubCommit
---@field files GithubDiffEntry[]

---Fetch the changed files at a given commit
---@param rev Rev
---@param callback fun(files: FileEntry[])
function OctoPullRequest:get_commit_changed_files(rev, callback)
  local url = string.format("repos/%s/commits/%s", self.repo, rev.commit)
  gh.run {
    args = { "api", "--paginate", url, "--jq", "." },
    cb = function(output, stderr)
      if stderr and not utils.is_blank(stderr) then
        utils.error(stderr)
      elseif output then
        local FileEntry = require("octo.reviews.file-entry").FileEntry
        ---@type GithubCommit
        local results = vim.fn.json_decode(output)
        ---@type FileEntry[]
        local files = {}
        if results.files then
          for _, result in ipairs(results.files) do
            local entry = FileEntry:new {
              path = result.filename,
              previous_path = result.previous_filename,
              patch = result.patch,
              pull_request = self,
              status = utils.file_status_map[result.status],
              stats = {
                additions = result.additions,
                deletions = result.deletions,
                changes = result.changes,
              },
            }
            table.insert(files, entry)
          end
          callback(files)
        end
      end
    end,
  }
end

return M
