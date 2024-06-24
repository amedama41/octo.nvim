local M = {}

---@class CommentMetadata
---@field id string
---@field author string
---@field savedBody string
---@field body string
---@field dirty boolean
---@field extmark integer
---@field startLine integer?
---@field endLine integer?
---@field namespace integer
---@field reactionGroups table[]
---@field reactionLine integer?
---@field viewerCanUpdate boolean
---@field viewerCanDelete boolean
---@field viewerDidAuthor boolean
---@field kind "IssueComment"|"PullRequestComment"|"PullRequestReview"|"PullRequestReviewComment"
---@field replyTo { id: string, url: string }?
---@field replyToRest string?
---@field reviewId string?
---@field path string?
---@field subjectType PullRequestReviewThreadSubjectType?
---@field diffSide string?
---@field snippetStartLine integer?
---@field snippetEndLine integer?
---@field bufferStartLine integer?
---@field bufferEndLine integer?
local CommentMetadata = {}
CommentMetadata.__index = CommentMetadata

---@class CommentMetadataOpts
---@field id string
---@field author string
---@field savedBody string
---@field body string
---@field dirty boolean
---@field extmark integer
---@field namespace integer
---@field reactionGroups table[]
---@field reactionLine integer?
---@field viewerCanUpdate boolean
---@field viewerCanDelete boolean
---@field viewerDidAuthor boolean
---@field kind "IssueComment"|"PullRequestComment"|"PullRequestReview"|"PullRequestReviewComment"
---@field replyTo { id: string, url: string }?
---@field replyToRest string?
---@field reviewId string?
---@field path string?
---@field subjectType PullRequestReviewThreadSubjectType?
---@field diffSide DiffSide?
---@field snippetStartLine integer?
---@field snippetEndLine integer?

---CommentMetadata constructor.
---@param opts CommentMetadataOpts
---@return CommentMetadata
function CommentMetadata:new(opts)
  local this = {
    author = opts.author,
    id = opts.id,
    dirty = opts.dirty or false,
    savedBody = opts.savedBody,
    body = opts.body,
    extmark = opts.extmark,
    namespace = opts.namespace,
    viewerCanUpdate = opts.viewerCanUpdate,
    viewerCanDelete = opts.viewerCanDelete,
    viewerDidAuthor = opts.viewerDidAuthor,
    reactionLine = opts.reactionLine,
    reactionGroups = opts.reactionGroups,
    kind = opts.kind,
    replyTo = opts.replyTo,
    replyToRest = opts.replyToRest,
    reviewId = opts.reviewId,
    path = opts.path,
    subjectType = opts.subjectType,
    diffSide = opts.diffSide,
    startLine = opts.startLine,
    endLine = opts.endLine,
    snippetStartLine = opts.snippetStartLine,
    snippetEndLine = opts.snippetEndLine,
  }
  setmetatable(this, self)
  return this
end

M.CommentMetadata = CommentMetadata

return M
