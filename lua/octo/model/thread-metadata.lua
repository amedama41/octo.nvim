local M = {}

---@class ThreadMetadata
---@field threadId string|nil
---@field replyTo string
---@field replyToRest string?
---@field reviewId string
---@field path string
---@field line number
---@field bufferStartLine integer line of thread hreader
---@field bufferEndLine integer line which thread end (inclusive)
local ThreadMetadata = {}
ThreadMetadata.__index = ThreadMetadata

---@class ThreadMetadataOpts
---@field threadId string|nil
---@field replyTo string
---@field replyToRest string?
---@field reviewId string
---@field path string
---@field line integer
---@field bufferStartLine integer
---@field bufferEndLine integer

---ThreadMetadata constructor.
---@param opts ThreadMetadataOpts
---@return ThreadMetadata
function ThreadMetadata:new(opts)
  local this = {
    threadId = opts.threadId,
    replyTo = opts.replyTo,
    replyToRest = opts.replyToRest,
    reviewId = opts.reviewId,
    path = opts.path,
    line = opts.line,
    bufferStartLine = opts.bufferStartLine,
    bufferEndLine = opts.bufferEndLine,
  }
  setmetatable(this, self)
  return this
end

M.ThreadMetadata = ThreadMetadata

return M
