local M = {}

---@alias AddReactionMutationResponse GraphQLResponse<{ addReaction: { subject: { reactionGroups: ReactionGroup[] } } }>

-- https://docs.github.com/en/graphql/reference/mutations#addreaction
M.add_reaction_mutation = [[
  mutation {
    addReaction(input: {subjectId: "%s", content: %s}) {
      subject {
        reactionGroups {
          content
          viewerHasReacted
          users {
            totalCount
          }
        }
      }
    }
  }
]]

---@alias RemoveReactionMutationResponse GraphQLResponse<{ removeReaction: { subject: { reactionGroups: ReactionGroup[] } } }>

-- https://docs.github.com/en/graphql/reference/mutations#removereaction
M.remove_reaction_mutation = [[
  mutation {
    removeReaction(input: {subjectId: "%s", content: %s}) {
      subject {
        reactionGroups {
          content
          viewerHasReacted
          users {
            totalCount
          }
        }
      }
    }
  }
]]

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/mutations#resolvereviewthread
M.resolve_review_thread_mutation = [[
  mutation {
    resolveReviewThread(input: {threadId: "%s"}) {
      thread {
        originalStartLine
        originalLine
        isOutdated
        isResolved
        path
        pullRequest {
          reviewThreads(last:100) {
            nodes {
              id
              path
              diffSide
              startDiffSide
              line
              originalLine
              startLine
              originalStartLine
              isResolved
              isCollapsed
              isOutdated
              comments(first:100) {
                nodes {
                  id
                  body
                  diffHunk
                  createdAt
                  lastEditedAt
                  originalCommit {
                    oid
                    abbreviatedOid
                  }
                  author {login}
                  authorAssociation
                  viewerDidAuthor
                  viewerCanUpdate
                  viewerCanDelete
                  state
                  url
                  replyTo { id url }
                  pullRequestReview {
                    id
                    state
                  }
                  path
                  reactionGroups {
                    content
                    viewerHasReacted
                    users {
                      totalCount
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
]]

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/mutations#unresolvereviewthread
M.unresolve_review_thread_mutation = [[
  mutation {
    unresolveReviewThread(input: {threadId: "%s"}) {
      thread {
        originalStartLine
        originalLine
        isOutdated
        isResolved
        path
        pullRequest {
          reviewThreads(last:100) {
            nodes {
              id
              path
              diffSide
              startDiffSide
              line
              originalLine
              startLine
              originalStartLine
              isResolved
              isCollapsed
              isOutdated
              comments(first:100) {
                nodes {
                  id
                  body
                  diffHunk
                  originalCommit {
                    oid
                    abbreviatedOid
                  }
                  createdAt
                  lastEditedAt
                  author {login}
                  authorAssociation
                  viewerDidAuthor
                  viewerCanUpdate
                  viewerCanDelete
                  state
                  url
                  replyTo { id url }
                  pullRequestReview {
                    id
                    state
                  }
                  path
                  reactionGroups {
                    content
                    viewerHasReacted
                    users {
                      totalCount
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
]]

---@alias StartReviewMutationResponse GraphQLResponse<{ addPullRequestReview: { pullRequestReview: { id: string, state: string, pullRequest: { reviewThreads: { nodes: PullRequestReviewThread[] } } } } }>

-- https://docs.github.com/en/graphql/reference/mutations#addpullrequestreview
M.start_review_mutation = [[
  mutation {
    addPullRequestReview(input: {pullRequestId: "%s"}) {
      pullRequestReview {
        id
        state
        pullRequest {
          reviewThreads(last:100) {
            nodes {
              id
              path
              line
              originalLine
              startLine
              originalStartLine
              diffSide
              startDiffSide
              isResolved
              resolvedBy { login }
              isCollapsed
              isOutdated
              subjectType
              comments(first:100) {
                nodes {
                  id
                  body
                  diffHunk
                  createdAt
                  lastEditedAt
                  originalCommit {
                    oid
                    abbreviatedOid
                  }
                  author {login}
                  authorAssociation
                  viewerDidAuthor
                  viewerCanUpdate
                  viewerCanDelete
                  state
                  url
                  replyTo { id url }
                  pullRequestReview {
                    id
                    state
                  }
                  path
                  subjectType
                  reactionGroups {
                    content
                    viewerHasReacted
                    users {
                      totalCount
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#markfileasviewed
M.mark_file_as_viewed_mutation = [[
  mutation {
    markFileAsViewed(input: {path: "%s", pullRequestId: "%s"}) {
      pullRequest {
        files(first:100){
          nodes {
            path
            viewerViewedState
          }
        }
      }
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#unmarkfileasviewed
M.unmark_file_as_viewed_mutation = [[
  mutation {
    unmarkFileAsViewed(input: {path: "%s", pullRequestId: "%s"}) {
      pullRequest {
        files(first:100){
          nodes {
            path
            viewerViewedState
          }
        }
      }
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#addpullrequestreview
M.submit_pull_request_review_mutation = [[
  mutation {
    submitPullRequestReview(input: {pullRequestReviewId: "%s", event: %s, body: "%s"}) {
      pullRequestReview {
        id
        state
      }
    }
  }
]]

M.delete_pull_request_review_mutation = [[
mutation {
  deletePullRequestReview(input: {pullRequestReviewId: "%s"}) {
    pullRequestReview {
      id
      state
    }
  }
}
]]

-- https://docs.github.com/en/graphql/reference/mutations#addpullrequestreviewthread
M.add_pull_request_review_thread_mutation = [[
mutation {
  addPullRequestReviewThread(input: { pullRequestReviewId: "%s", body: "%s", path: "%s", subjectType: %s, side: %s, line:%d}) {
    thread {
      id
      comments(last:100) {
        nodes {
          id
          body
          diffHunk
          createdAt
          lastEditedAt
          commit {
            oid
            abbreviatedOid
          }
          author {login}
          authorAssociation
          viewerDidAuthor
          viewerCanUpdate
          viewerCanDelete
          state
          url
          replyTo { id url }
          pullRequestReview {
            id
            state
          }
          path
          reactionGroups {
            content
            viewerHasReacted
            users {
              totalCount
            }
          }
        }
      }
      pullRequest {
        reviewThreads(last:100) {
          nodes {
            id
            path
            diffSide
            startDiffSide
            line
            originalLine
            startLine
            originalStartLine
            isResolved
            isCollapsed
            isOutdated
            comments(first:100) {
              nodes {
                id
                body
                diffHunk
                createdAt
                lastEditedAt
                originalCommit {
                  oid
                  abbreviatedOid
                }
                author {login}
                authorAssociation
                viewerDidAuthor
                viewerCanUpdate
                viewerCanDelete
                state
                url
                replyTo { id url }
                pullRequestReview {
                  id
                  state
                }
                path
                reactionGroups {
                  content
                  viewerHasReacted
                  users {
                    totalCount
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
]]

-- https://docs.github.com/en/graphql/reference/mutations#addpullrequestreviewthread
M.add_pull_request_review_multiline_thread_mutation = [[
mutation {
  addPullRequestReviewThread(input: { pullRequestReviewId: "%s", body: "%s", path: "%s", startSide: %s, side: %s, startLine: %d, line:%d}) {
    thread {
      id
      comments(last:100) {
        nodes {
          id
          body
          diffHunk
          createdAt
          lastEditedAt
          commit {
            oid
            abbreviatedOid
          }
          author {login}
          authorAssociation
          viewerDidAuthor
          viewerCanUpdate
          viewerCanDelete
          state
          url
          replyTo { id url }
          pullRequestReview {
            id
            state
          }
          path
          reactionGroups {
            content
            viewerHasReacted
            users {
              totalCount
            }
          }
        }
      }
      pullRequest {
        reviewThreads(last:100) {
          nodes {
            id
            path
            diffSide
            startDiffSide
            line
            originalLine
            startLine
            originalStartLine
            isResolved
            isCollapsed
            isOutdated
            comments(first:100) {
              nodes {
                id
                body
                diffHunk
                createdAt
                lastEditedAt
                originalCommit {
                  oid
                  abbreviatedOid
                }
                author {login}
                authorAssociation
                viewerDidAuthor
                viewerCanUpdate
                viewerCanDelete
                state
                url
                replyTo { id url }
                pullRequestReview {
                  id
                  state
                }
                path
                reactionGroups {
                  content
                  viewerHasReacted
                  users {
                    totalCount
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
]]

---@class UpdateIssueComment
---@field id string
---@field body string

---@alias AddIssueCommentMutationResponse GraphQLResponse<{ addComment: { commentEdge: { node: UpdateIssueComment } } }>

-- https://docs.github.com/en/graphql/reference/mutations#addcomment
M.add_issue_comment_mutation = [[
  mutation {
    addComment(input: {subjectId: "%s", body: "%s"}) {
      commentEdge {
        node {
          id
          body
        }
      }
    }
  }
]]

---@alias UpdateIssueCommentMutationResponse GraphQLResponse<{ updateIssueComment: { issueComment: UpdateIssueComment } }>

-- https://docs.github.com/en/graphql/reference/mutations#updateissuecomment
M.update_issue_comment_mutation = [[
  mutation {
    updateIssueComment(input: {id: "%s", body: "%s"}) {
      issueComment {
        id
        body
      }
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#updatepullrequestreviewcomment
M.update_pull_request_review_comment_mutation = [[
  mutation {
    updatePullRequestReviewComment(input: {pullRequestReviewCommentId: "%s", body: "%s"}) {
      pullRequestReviewComment {
        id
        body
        pullRequest {
          reviewThreads(last:100) {
            nodes {
              id
              path
              diffSide
              startDiffSide
              line
              originalLine
              startLine
              originalStartLine
              isResolved
              isCollapsed
              isOutdated
              comments(first:100) {
                nodes {
                  id
                  body
                  diffHunk
                  createdAt
                  lastEditedAt
                  originalCommit {
                    oid
                    abbreviatedOid
                  }
                  author {login}
                  authorAssociation
                  viewerDidAuthor
                  viewerCanUpdate
                  viewerCanDelete
                  state
                  url
                  replyTo { id url }
                  pullRequestReview {
                    id
                    state
                  }
                  path
                  reactionGroups {
                    content
                    viewerHasReacted
                    users {
                      totalCount
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
]]

---@alias UpdatePullRequestReviewMutationResponse GraphQLResponse<{ updatePullRequestReview: { pullRequestReview: { id: string, state: PullRequestReviewState, body: string } } }>

-- https://docs.github.com/en/graphql/reference/mutations#updatepullrequestreview
M.update_pull_request_review_mutation = [[
  mutation {
    updatePullRequestReview(input: {pullRequestReviewId: "%s", body: "%s"}) {
      pullRequestReview {
        id
        state
        body
      }
    }
  }
]]

---TODO: exclude resolvedBy
---@alias AddPullRequestReviewCommentMutationResponse GraphQLResponse<{ addPullRequestReviewComment: { comment: { id: string, body: string, pullRequest: { reviewThreads: { nodes: PullRequestReviewThread[] } } } } }>

-- https://docs.github.com/en/graphql/reference/mutations#addpullrequestreviewcomment
M.add_pull_request_review_comment_mutation = [[
  mutation {
    addPullRequestReviewComment(input: {inReplyTo: "%s", body: "%s", pullRequestReviewId: "%s"}) {
      comment {
        id
        body
        pullRequest {
          reviewThreads(last:100) {
            nodes {
              id
              path
              diffSide
              startDiffSide
              line
              originalLine
              startLine
              originalStartLine
              isResolved
              isCollapsed
              isOutdated
              subjectType
              comments(first:100) {
                nodes {
                  id
                  body
                  diffHunk
                  createdAt
                  lastEditedAt
                  originalCommit {
                    oid
                    abbreviatedOid
                  }
                  author {login}
                  authorAssociation
                  viewerDidAuthor
                  viewerCanUpdate
                  viewerCanDelete
                  state
                  url
                  replyTo { id url }
                  pullRequestReview {
                    id
                    state
                  }
                  path
                  subjectType
                  reactionGroups {
                    content
                    viewerHasReacted
                    users {
                      totalCount
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#addpullrequestreviewcomment
M.add_pull_request_review_commit_thread_mutation = [[
  mutation {
    addPullRequestReviewComment(input: {commitOID: "%s", body: "%s", pullRequestReviewId: "%s", path: "%s", position: %d }) {
      comment {
        id
        body
        pullRequest {
          reviewThreads(last:100) {
            nodes {
              id
              path
              diffSide
              startDiffSide
              line
              originalLine
              startLine
              originalStartLine
              isResolved
              isCollapsed
              isOutdated
              comments(first:100) {
                nodes {
                  id
                  body
                  diffHunk
                  createdAt
                  lastEditedAt
                  originalCommit {
                    oid
                    abbreviatedOid
                  }
                  author {login}
                  authorAssociation
                  viewerDidAuthor
                  viewerCanUpdate
                  viewerCanDelete
                  state
                  url
                  replyTo { id url }
                  pullRequestReview {
                    id
                    state
                  }
                  path
                  reactionGroups {
                    content
                    viewerHasReacted
                    users {
                      totalCount
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
]]

-- M.add_pull_request_review_comment_mutation =
-- [[
--   mutation {
--     addPullRequestReviewThreadReply(input: { pullRequestReviewThreadId: "%s", body: "%s"}) {
--       comment{
--         id
--         body
--       }
--     }
--   }
-- ]]

-- https://docs.github.com/en/graphql/reference/mutations#deleteissuecomment
M.delete_issue_comment_mutation = [[
  mutation {
    deleteIssueComment(input: {id: "%s"}) {
      clientMutationId
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#deletepullrequestreviewcomment
M.delete_pull_request_review_comment_mutation = [[
  mutation {
    deletePullRequestReviewComment(input: {id: "%s"}) {
      pullRequestReview {
        id
        pullRequest {
          id
          reviewThreads(last:100) {
            nodes {
              id
              path
              diffSide
              startDiffSide
              line
              originalLine
              startLine
              originalStartLine
              isResolved
              isCollapsed
              isOutdated
              comments(first:100) {
                nodes {
                  id
                  body
                  diffHunk
                  createdAt
                  lastEditedAt
                  originalCommit {
                    oid
                    abbreviatedOid
                  }
                  author {login}
                  authorAssociation
                  viewerDidAuthor
                  viewerCanUpdate
                  viewerCanDelete
                  state
                  url
                  replyTo { id url }
                  pullRequestReview {
                    id
                    state
                  }
                  path
                  reactionGroups {
                    content
                    viewerHasReacted
                    users {
                      totalCount
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
]]

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/mutations#updateissue
M.update_issue_mutation = [[
  mutation {
    updateIssue(input: {id: "%s", title: "%s", body: "%s"}) {
      issue {
        id
        number
        state
        title
        body
        repository { nameWithOwner }
      }
    }
  }
]]

---@alias CreateIssueMutationResponse GraphQLResponse<{ createIssue: { issue: Issue } }>

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/mutations#createissue
M.create_issue_mutation = [[
  mutation {
    createIssue(input: {repositoryId: "%s", title: "%s", body: "%s"}) {
      issue {
        id
        number
        state
        title
        body
        createdAt
        closedAt
        updatedAt
        url
        viewerDidAuthor
        viewerCanUpdate
        milestone {
          title
          state
        }
        author {
          login
        }
        participants(first:10) {
          nodes {
            login
          }
        }
        reactionGroups {
          content
          viewerHasReacted
          users {
            totalCount
          }
        }
        projectCards(last: 20) {
          nodes {
            id
            state
            column {
              name
            }
            project {
              name
            }
          }
        }
        repository {
          nameWithOwner
        }
        timelineItems(first: 100) {
          nodes {
            __typename
            ... on LabeledEvent {
              actor {
                login
              }
              createdAt
              label {
                color
                name
              }
            }
            ... on UnlabeledEvent {
              actor {
                login
              }
              createdAt
              label {
                color
                name
              }
            }
            ... on IssueComment {
              id
              body
              createdAt
              reactionGroups {
                content
                viewerHasReacted
                users {
                  totalCount
                }
              }
              author {
                login
              }
              viewerDidAuthor
              viewerCanUpdate
              viewerCanDelete
            }
            ... on ClosedEvent {
              createdAt
              actor {
                login
              }
            }
            ... on ReopenedEvent {
              createdAt
              actor {
                login
              }
            }
            ... on AssignedEvent {
              actor {
                login
              }
              assignee {
                ... on Organization { name }
                ... on Bot { login }
                ... on User {
                  login
                  isViewer
                }
                ... on Mannequin { login }
              }
              createdAt
            }
          }
        }
        labels(first: 20) {
          nodes {
            color
            name
          }
        }
        assignees(first: 20) {
          nodes {
            id
            login
            isViewer
          }
        }
      }
    }
  }
]]

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/mutations#updateissue
M.update_issue_mutation = [[
  mutation {
    updateIssue(input: {id: "%s", title: "%s", body: "%s"}) {
      issue {
        id
        number
        state
        title
        body
        repository {
          nameWithOwner
        }
      }
    }
  }
]]

---@class Issue
---@field id string
---@field number integer
---@field state IssueState
---@field title string
---@field body string
---@field createdAt string
---@field closedAt string?
---@field updatedAt string
---@field url string
---@field viewerDidAuthor boolean
---@field viewerCanUpdate boolean
---@field repository { nameWithOwner: string }
---@field milestone { title: string, state: MilestoneState }?
---@field author { login: string }
---@field participants { nodes: { login: string }[] }
---@field reactionGroups ReactionGroup[]?
---@field projectCards { nodes: ProjectCard[] }
---@field timelineItems { pageInfo: PageInfo?, nodes: IssueTimelineItems[] }
---@field labels { nodes: Label[] }?
---@field assignee { nodes: { id: string, login: string, isViewer: boolean }[] }

---@alias UpdateIssueStateMutationResponse GraphQLResponse<{ updateIssue: { issue: Issue } }>

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/mutations#updateissue
M.update_issue_state_mutation = [[
  mutation {
    updateIssue(input: {id: "%s", state: %s}) {
      issue {
        id
        number
        state
        title
        body
        createdAt
        closedAt
        updatedAt
        url
        viewerDidAuthor
        viewerCanUpdate
        repository {
          nameWithOwner
        }
        milestone {
          title
          state
        }
        author {
          login
        }
        participants(first:10) {
          nodes {
            login
          }
        }
        reactionGroups {
          content
          viewerHasReacted
          users {
            totalCount
          }
        }
        projectCards(last: 20) {
          nodes {
            id
            state
            column {
              name
            }
            project {
              name
            }
          }
        }
        timelineItems(last: 100) {
          nodes {
            __typename
            ... on LabeledEvent {
              actor {
                login
              }
              createdAt
              label {
                color
                name
              }
            }
            ... on UnlabeledEvent {
              actor {
                login
              }
              createdAt
              label {
                color
                name
              }
            }
            ... on IssueComment {
              id
              body
              createdAt
              reactionGroups {
                content
                viewerHasReacted
                users {
                  totalCount
                }
              }
              author {
                login
              }
              viewerDidAuthor
              viewerCanUpdate
              viewerCanDelete
            }
            ... on ClosedEvent {
              createdAt
              actor {
                login
              }
            }
            ... on ReopenedEvent {
              createdAt
              actor {
                login
              }
            }
            ... on AssignedEvent {
              actor {
                login
              }
              assignee {
                ... on Organization { name }
                ... on Bot { login }
                ... on User {
                  login
                  isViewer
                }
                ... on Mannequin { login }
              }
              createdAt
            }
          }
        }
        labels(first: 20) {
          nodes {
            color
            name
          }
        }
        assignees(first: 20) {
          nodes {
            id
            login
            isViewer
          }
        }
      }
    }
  }
]]

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/mutations#updatepullrequest
M.update_pull_request_mutation = [[
  mutation {
    updatePullRequest(input: {pullRequestId: "%s", title: "%s", body: "%s"}) {
      pullRequest {
        id
        number
        state
        title
        body
      }
    }
  }
]]

---@class PullRequest
---@field id string
---@field isDraft boolean
---@field number integer
---@field state PullRequestState
---@field title string
---@field body string
---@field createdAt string
---@field closedAt string?
---@field updatedAt string
---@field url string
---@field repository { nameWithOwner: string }
---@field files { nodes: PullRequestChangedFile[] }
---@field merged boolean
---@field mergedBy { name: string }|{ login: string }|{ login: string, isViewer: boolean }?
---@field participants { nodes: { login: string }[] }
---@field additions integer
---@field deletions integer
---@field commits { totalCount: integer }
---@field changedFiles integer
---@field headRefName string
---@field headRefOid string
---@field baseRefName string
---@field baseRefOid string
---@field baseRepository { name: string, nameWithOwner: string }
---@field milestone { title: string, state: MilestoneState }?
---@field author { login: string }?
---@field viewerDidAuthor boolean
---@field viewerCanUpdate boolean
---@field reactionGroups ReactionGroup[]?
---@field projectCards { nodes: ProjectCard[] }
---@field reviewDecision PullRequestReviewDecision
---@field timelineItems { pageInfo: PageInfo, nodes: PullRequestTimelineItems[] }
---@field labels { nodes: Label[] }?
---@field assignees { nodes: { id: string, login: string, isViewer: boolean }[] }
---@field reviewRequests { totalCount: integer, nodes: { requestedReviewer: { login: string, isViewer: boolean }|{ name: string } }[] }

---@alias UpdatePullRequestStateMutationResponse GraphQLResponse<{ updatePullRequest: { pullRequest: PullRequest } }>

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/mutations#updatepullrequest
M.update_pull_request_state_mutation = [[
  mutation {
    updatePullRequest(input: {pullRequestId: "%s", state: %s}) {
      pullRequest {
        id
        isDraft
        number
        state
        title
        body
        createdAt
        closedAt
        updatedAt
        url
        repository { nameWithOwner }
        files(first:100) {
          nodes {
            path
            viewerViewedState
          }
        }
        merged
        mergedBy {
          ... on Organization { name }
          ... on Bot { login }
          ... on User {
            login
            isViewer
          }
          ... on Mannequin { login }
        }
        participants(first:10) {
          nodes {
            login
          }
        }
        additions
        deletions
        commits {
          totalCount
        }
        changedFiles
        headRefName
        headRefOid
        baseRefName
        baseRefOid
        baseRepository {
          name
          nameWithOwner
        }
        milestone {
          title
          state
        }
        author {
          login
        }
        viewerDidAuthor
        viewerCanUpdate
        reactionGroups {
          content
          viewerHasReacted
          users {
            totalCount
          }
        }
        projectCards(last: 20) {
          nodes {
            id
            state
            column {
              name
            }
            project {
              name
            }
          }
        }
        timelineItems(last: 100) {
          nodes {
            __typename
            ... on PullRequestReview {
              id
              body
              createdAt
              viewerCanUpdate
              viewerCanDelete
              reactionGroups {
                content
                viewerHasReacted
                users {
                  totalCount
                }
              }
              author {
                login
              }
              viewerDidAuthor
              state
              comments(last:100) {
                totalCount
                nodes{
                  id
                  url
                  replyTo { id url }
                  body
                  commit {
                    oid
                    abbreviatedOid
                  }
                  author { login }
                  createdAt
                  lastEditedAt
                  authorAssociation
                  viewerDidAuthor
                  viewerCanUpdate
                  viewerCanDelete
                  originalPosition
                  position
                  state
                  outdated
                  diffHunk
                  reactionGroups {
                    content
                    viewerHasReacted
                    users {
                      totalCount
                    }
                  }
                }
              }
            }
          }
        }
        reviewDecision
        labels(first: 20) {
          nodes {
            color
            name
          }
        }
        assignees(first: 20) {
          nodes {
            id
            login
            isViewer
          }
        }
        reviewRequests(first: 20) {
          totalCount
          nodes {
            requestedReviewer {
              ... on User {
                login
                isViewer
              }
              ... on Mannequin { login }
              ... on Team { name }
            }
          }
        }
      }
    }
  }
]]

---@alias PullRequestReviewState "APPROVED"|"CHANGES_REQUESTED"|"COMMENTED"|"DISMISSED"|"PENDING"
---@alias PullRequestReviewCommentState "PENDING"|"SUBMITTED"
---@alias CommentAuthorAssociation "COLLABORATOR"|"CONTRIBUTOR"|"FIRST_TIMER"|"FIRST_TIME_CONTRIBUTOR"|"MANNEQUIN"|"MEMBER"|"NONE"|"OWNER"
---@alias DiffSide "LEFT"|"RIGHT"
---@alias PullRequestReviewThreadSubjectType "FILE"|"LINE"

---@class PullRequestReviewComment
---@field id string
---@field body string
---@field diffHunk string
---@field author { login: string }?
---@field createdAt string
---@field lastEditedAt string?
---@field authorAssociation CommentAuthorAssociation
---@field viewerDidAuthor boolean
---@field viewerCanUpdate boolean
---@field viewerCanDelete boolean
---@field state PullRequestReviewCommentState
---@field url string
---@field replyTo { id: string, url: string }?
---@field reactionGroups ReactionGroup[]?

---@class PullRequestReviewCommentForPRReviewThread: PullRequestReviewComment
---@field originalCommit { oid: string, abbreviatedOid: string }?
---@field pullRequestReview { id: string, state: PullRequestReviewState }
---@field path string
---@field subjectType PullRequestReviewThreadSubjectType

---@class PullRequestReviewCommentForPRReview: PullRequestReviewComment
---@field commit { oid: string, abbreviatedOid: string }?
---@field originalPosition integer
---@field position integer?
---@field outdated boolean

---@class PullRequestReviewThread
---@field id string
---@field path string
---@field diffSide DiffSide
---@field startDiffSide DiffSide?
---@field line integer?
---@field originalLine integer
---@field startLine integer?
---@field originalStartLine integer?
---@field isResolved boolean
---@field resolvedBy { login: string }?
---@field isCollapsed boolean
---@field isOutdated boolean
---@field subjectType PullRequestReviewThreadSubjectType
---@field comments { nodes: PullRequestReviewCommentForPRReviewThread[] }

---@class BriefPullRequestReview
---@field id string
---@field viewerDidAuthor boolean

---@class GraphQLResponse<T>: { data: T, errors: any }

---@alias PendingReviewThreadsQueryResponse GraphQLResponse<{ repository: { pullRequest: { reviews: { nodes: BriefPullRequestReview[] }, reviewThreads: { nodes: PullRequestReviewThread[] } } } }>

-- https://docs.github.com/en/graphql/reference/objects#pullrequestreviewthread
M.pending_review_threads_query = [[
query {
  repository(owner:"%s", name:"%s") {
    pullRequest (number: %d){
      reviews(first:100, states:PENDING) {
        nodes {
          id
          viewerDidAuthor
        }
      }
      reviewThreads(last:100) {
        nodes {
          id
          path
          diffSide
          startDiffSide
          line
          originalLine
          startLine
          originalStartLine
          isResolved
          resolvedBy { login }
          isCollapsed
          isOutdated
          subjectType
          comments(first:100) {
            nodes {
              id
              body
              diffHunk
              createdAt
              lastEditedAt
              originalCommit {
                oid
                abbreviatedOid
              }
              author {login}
              authorAssociation
              viewerDidAuthor
              viewerCanUpdate
              viewerCanDelete
              state
              url
              replyTo { id url }
              pullRequestReview {
                id
                state
              }
              path
              subjectType
              reactionGroups {
                content
                viewerHasReacted
                users {
                  totalCount
                }
              }
            }
          }
        }
      }
    }
  }
}
]]

---@alias ReviewThreadsQueryResponse GraphQLResponse<{ repository: { pullRequest: { reviewThreads: { nodes: BriefPullRequestReview[] } } } }>

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/objects#pullrequestreviewthread
M.review_threads_query = [[
query($endCursor: String) {
  repository(owner:"%s", name:"%s") {
    pullRequest(number:%d) {
      reviewThreads(last:80) {
        nodes {
          id
          isResolved
          isCollapsed
          isOutdated
          path
          resolvedBy { login }
          line
          originalLine
          startLine
          originalStartLine
          diffSide
          comments(first: 100, after: $endCursor) {
            nodes{
              id
              body
              createdAt
              lastEditedAt
              state
              originalCommit {
                oid
                abbreviatedOid
              }
              pullRequestReview {
                id
                state
              }
              path
              url
              replyTo { id url }
              author { login }
              authorAssociation
              viewerDidAuthor
              viewerCanUpdate
              viewerCanDelete
              outdated
              diffHunk
              reactionGroups {
                content
                viewerHasReacted
                users {
                  totalCount
                }
              }
            }
            pageInfo {
              hasNextPage
              endCursor
            }
          }
        }
      }
    }
  }
}
]]

---@alias ReactionContent "CONFUSED"|"EYES"|"HEART"|"HOORAY"|"LAUGH"|"ROCKET"|"THUMBS_DOWN"|"THUMBS_UP"
---@alias PullRequestState "CLOSED"|"MERGED"|"OPEN"
---@alias PullRequestReviewDecision "APPROVED"|"CHANGES_REQUESTED"|"REVIEW_REQUIRED"
---@alias FileViewedState "DISMISSED"|"UNVIEWED"|"VIEWED"
---@alias MilestoneState "CLOSED"|"OPEN"
---@alias ProjectCardState "CONTENT_ONLY"|"NOTE_ONLY"|"REDACTED"

---@class ProjectCard
---@field id string
---@field state ProjectCardState?
---@field column { name: string }?
---@field project { name: string }

---@class PullRequestChangedFile
---@field path string
---@field viewerViewedState FileViewedState

---@class ReactionGroup
---@field content ReactionContent
---@field viewerHasReacted boolean
---@field users { totalCount: integer }

---@class Label
---@field name string
---@field color string

---@class Commit
---@field messageHeadline string
---@field committedDate string
---@field oid string
---@field abbreviatedOid string
---@field changedFiles integer
---@field additions integer
---@field deletions integer
---@field committer { user: { login: string }? }?

---@class LabeledEvent
---@field __typename "LabeledEvent"
---@field actor { login: string }?
---@field createdAt string
---@field label Label

---@class UnlabeledEvent
---@field __typename "UnlabeledEvent"
---@field actor { login: string }?
---@field createdAt string
---@field label Label

---@class AssignedEvent
---@field __typename "AssignedEvent"
---@field actor { login: string }?
---@field assignee { name: string }|{ login: string }|{ login: string, isViewer: boolean }?
---@field createdAt string

---@class PullRequestCommit
---@field __typename "PullRequestCommit"
---@field commit Commit

---@class MergedEvent
---@field __typename "MergedEvent"
---@field createdAt string
---@field actor { login: string }?
---@field commit { oid: string, abbreviatedOid: string }
---@field mergeRefName string

---@class ClosedEvent
---@field __typename "ClosedEvent"
---@field actor { login: string }?
---@field createdAt string

---@class ReopenedEvent
---@field __typename "ReopenedEvent"
---@field actor { login: string }?
---@field createdAt string

---@class ReviewRequestedEvent
---@field __typename "ReviewRequestedEvent"
---@field createdAt string
---@field actor { login: string }?
---@field requestedReviewer { login: string, isViewer: boolean}|{ login: string }|{ name: string }?

---@class ReviewRequestedRemovedEvent
---@field __typename "ReviewRequestedRemovedEvent"
---@field createdAt string
---@field actor { login: string }?
---@field requestedReviewer { login: string, isViewer: boolean}|{ login: string }|{ name: string }?

---@class ReviewDismissedEvent
---@field __typename "ReviewDismissedEvent"
---@field createdAt string
---@field actor { login: string }?
---@field dismissalMessage string?

---@class IssueComment
---@field id string
---@field body string
---@field createdAt string
---@field reactionGroups ReactionGroup[]?
---@field author { login: string }?
---@field viewerDidAuthor boolean
---@field viewerCanUpdate boolean
---@field viewerCanDelete boolean

---@class IssueCommentWithTypename: IssueComment
---@field __typename "IssueComment"

---@class PageInfo
---@field hasNextPage boolean
---@field endCursor string?

---@class PullRequestReview
---@field id string
---@field body string
---@field createdAt string
---@field viewerCanUpdate boolean
---@field viewerCanDelete boolean
---@field reactionGroups ReactionGroup[]?
---@field author { login: string }?
---@field viewerDidAuthor boolean
---@field state PullRequestReviewState
---@field comments { totalCount: integer, nodes: PullRequestReviewCommentForPRReview[] }

---@class PullRequestReviewWithTypename: PullRequestReview
---@field __typename "PullRequestReview"

---@alias PullRequestTimelineItems LabeledEvent|UnlabeledEvent|AssignedEvent|PullRequestCommit|MergedEvent|ClosedEvent|ReopenedEvent|ReviewRequestedEvent|ReviewRequestedRemovedEvent|ReviewDismissedEvent|IssueCommentWithTypename|PullRequestReviewWithTypename

---@class PullRequestWithReviewThreads: PullRequest
---@field reviewThreads { nodes: PullRequestReviewThread[] }

---@alias PullRequestQueryResponse GraphQLResponse<{ repository: { pullRequest: PullRequestWithReviewThreads } }>

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/objects#pullrequest
M.pull_request_query = [[
query($endCursor: String) {
  repository(owner: "%s", name: "%s") {
    pullRequest(number: %d) {
      id
      isDraft
      number
      state
      title
      body
      createdAt
      closedAt
      updatedAt
      url
      repository { nameWithOwner }
      files(first:100) {
        nodes {
          path
          viewerViewedState
        }
      }
      merged
      mergedBy {
        ... on Organization { name }
        ... on Bot { login }
        ... on User {
          login
          isViewer
        }
        ... on Mannequin { login }
      }
      participants(first:10) {
        nodes {
          login
        }
      }
      additions
      deletions
      commits {
        totalCount
      }
      changedFiles
      headRefName
      headRefOid
      baseRefName
      baseRefOid
      baseRepository {
        name
        nameWithOwner
      }
      milestone {
        title
        state
      }
      author {
        login
      }
      viewerDidAuthor
      viewerCanUpdate
      reactionGroups {
        content
        viewerHasReacted
        users {
          totalCount
        }
      }
      projectCards(last: 20) {
        nodes {
          id
          state
          column {
            name
          }
          project {
            name
          }
        }
      }
      %s
      timelineItems(first: 100, after: $endCursor) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          __typename
          ... on LabeledEvent {
            actor {
              login
            }
            createdAt
            label {
              color
              name
            }
          }
          ... on UnlabeledEvent {
            actor {
              login
            }
            createdAt
            label {
              color
              name
            }
          }
          ... on AssignedEvent {
            actor {
              login
            }
            assignee {
              ... on Organization { name }
              ... on Bot { login }
              ... on User {
                login
                isViewer
              }
              ... on Mannequin { login }
            }
            createdAt
          }
          ... on PullRequestCommit {
            commit {
              messageHeadline
              committedDate
              oid
              abbreviatedOid
              changedFiles
              additions
              deletions
              committer {
                user {
                  login
                }
              }
            }
          }
          ... on MergedEvent {
            createdAt
            actor {
              login
            }
            commit {
              oid
              abbreviatedOid
            }
            mergeRefName
          }
          ... on ClosedEvent {
            createdAt
            actor {
              login
            }
          }
          ... on ReopenedEvent {
            createdAt
            actor {
              login
            }
          }
          ... on ReviewRequestedEvent {
            createdAt
            actor {
              login
            }
            requestedReviewer {
              ... on User {
                login
                isViewer
              }
              ... on Mannequin { login }
              ... on Team { name }
            }
          }
          ... on ReviewRequestRemovedEvent {
            createdAt
            actor {
              login
            }
            requestedReviewer {
              ... on User {
                login
                isViewer
              }
              ... on Mannequin {
                login
              }
              ... on Team {
                name
              }
            }
          }
          ... on ReviewDismissedEvent {
            createdAt
            actor {
              login
            }
            dismissalMessage
          }
          ... on IssueComment {
            id
            body
            createdAt
            reactionGroups {
              content
              viewerHasReacted
              users {
                totalCount
              }
            }
            author {
              login
            }
            viewerDidAuthor
            viewerCanUpdate
            viewerCanDelete
          }
          ... on PullRequestReview {
            id
            body
            createdAt
            viewerCanUpdate
            viewerCanDelete
            reactionGroups {
              content
              viewerHasReacted
              users {
                totalCount
              }
            }
            author {
              login
            }
            viewerDidAuthor
            state
            comments(last:100) {
              totalCount
              nodes{
                id
                url
                replyTo { id url }
                body
                commit {
                  oid
                  abbreviatedOid
                }
                author { login }
                createdAt
                lastEditedAt
                authorAssociation
                viewerDidAuthor
                viewerCanUpdate
                viewerCanDelete
                originalPosition
                position
                state
                outdated
                diffHunk
                reactionGroups {
                  content
                  viewerHasReacted
                  users {
                    totalCount
                  }
                }
              }
            }
          }
        }
      }
      reviewDecision
      reviewThreads(last:100) {
        nodes {
          id
          isResolved
          isCollapsed
          isOutdated
          path
          resolvedBy { login }
          line
          originalLine
          startLine
          originalStartLine
          diffSide
          subjectType
          comments(first: 100) {
            nodes{
              id
              body
              createdAt
              lastEditedAt
              url
              replyTo { id url }
              state
              originalCommit {
                oid
                abbreviatedOid
              }
              pullRequestReview {
                id
                state
              }
              path
              subjectType
              author { login }
              authorAssociation
              viewerDidAuthor
              viewerCanUpdate
              viewerCanDelete
              outdated
              diffHunk
              reactionGroups {
                content
                viewerHasReacted
                users {
                  totalCount
                }
              }
            }
          }
        }
      }
      labels(first: 20) {
        nodes {
          color
          name
        }
      }
      assignees(first: 20) {
        nodes {
          id
          login
          isViewer
        }
      }
      reviewRequests(first: 20) {
        totalCount
        nodes {
          requestedReviewer {
            ... on User {
              login
              isViewer
            }
            ... on Mannequin { login }
            ... on Team { name }
          }
        }
      }
    }
  }
}
]]

---@alias IssueState "CLOSED"|"OPEN"
---@alias IssueTimelineItems LabeledEvent|UnlabeledEvent|IssueCommentWithTypename|ClosedEvent|ReopenedEvent|AssignedEvent

---@alias IssueQueryResponse GraphQLResponse<{ repository: { issue: Issue } }>

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/objects#issue
M.issue_query = [[
query($endCursor: String) {
  repository(owner: "%s", name: "%s") {
    issue(number: %d) {
      id
      number
      state
      title
      body
      createdAt
      closedAt
      updatedAt
      url
      viewerDidAuthor
      viewerCanUpdate
      repository {
        nameWithOwner
      }
      milestone {
        title
        state
      }
      author {
        login
      }
      participants(first:10) {
        nodes {
          login
        }
      }
      reactionGroups {
        content
        viewerHasReacted
        users {
          totalCount
        }
      }
      projectCards(last: 20) {
        nodes {
          id
          state
          column {
            name
          }
          project {
            name
          }
        }
      }
      %s
      timelineItems(first: 100, after: $endCursor) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          __typename
          ... on LabeledEvent {
            actor {
              login
            }
            createdAt
            label {
              color
              name
            }
          }
          ... on UnlabeledEvent {
            actor {
              login
            }
            createdAt
            label {
              color
              name
            }
          }
          ... on IssueComment {
            id
            body
            createdAt
            reactionGroups {
              content
              viewerHasReacted
              users {
                totalCount
              }
            }
            author {
              login
            }
            viewerDidAuthor
            viewerCanUpdate
            viewerCanDelete
          }
          ... on ClosedEvent {
            createdAt
            actor {
              login
            }
          }
          ... on ReopenedEvent {
            createdAt
            actor {
              login
            }
          }
          ... on AssignedEvent {
            actor {
              login
            }
            assignee {
              ... on Organization { name }
              ... on Bot { login }
              ... on User {
                login
                isViewer
              }
              ... on Mannequin { login }
            }
            createdAt
          }
        }
      }
      labels(first: 20) {
        nodes {
          color
          name
        }
      }
      assignees(first: 20) {
        nodes {
          id
          login
          isViewer
        }
      }
    }
  }
}
]]

---@alias IssueKindQueryResponse GraphQLResponse<{ repository: { issueOrPullRequest: { __typename: "Issue"|"PullRequest" } } }>

-- https://docs.github.com/en/graphql/reference/unions#issueorpullrequest
M.issue_kind_query = [[
query {
  repository(owner: "%s", name: "%s") {
    issueOrPullRequest(number: %d) {
      __typename
    }
  }
}
]]

---@class IssueSummary
---@field __typename "Issue"
---@field headRefName string
---@field baseRefName string
---@field createdAt string
---@field state IssueState
---@field number integer
---@field title string
---@field body string
---@field repository { nameWithOwner: string }
---@field author { login: string }
---@field authorAssociation CommentAuthorAssociation
---@field labels { nodes: Label[] }?

---@class PullRequestSummary
---@field __typename "PullRequest"
---@field createdAt string
---@field state PullRequestState
---@field number integer
---@field title string
---@field body string
---@field repository { nameWithOwner: string }
---@field author { login: string }
---@field authorAssociation CommentAuthorAssociation
---@field labels { nodes: Label[] }?

---@alias IssueSummaryQueryResponse GraphQLResponse<{ repository: { issueOrPullRequest: IssueSummary|PullRequestSummary } }>

-- https://docs.github.com/en/graphql/reference/unions#issueorpullrequest
M.issue_summary_query = [[
query {
  repository(owner: "%s", name: "%s") {
    issueOrPullRequest(number: %d) {
      ... on PullRequest {
        __typename
        headRefName
        baseRefName
        createdAt
        state
        number
        title
        body
        repository { nameWithOwner }
        author { login }
        authorAssociation
        labels(first: 20) {
          nodes {
            color
            name
          }
        }
      }
      ... on Issue {
        __typename
        createdAt
        state
        number
        title
        body
        repository { nameWithOwner }
        author { login }
        authorAssociation
        labels(first: 20) {
          nodes {
            color
            name
          }
        }
      }
    }
  }
}
]]

---@alias RepositoryIdQueryResponse GraphQLResponse<{ repository: { id: string } }>

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/objects#repository
M.repository_id_query = [[
query {
  repository(owner: "%s", name: "%s") {
    id
  }
}
]]

---@class IssueTemplate
---@field body string?
---@field about string?
---@field name string
---@field title string?

---@class PullRequestTemplate
---@field body string?
---@field filename string?

---@alias RepositoryTemplatesQueryResponse GraphQLResponse<{ repository: { issueTemplates: IssueTemplate[], pullRequestTemplates: PullRequestTemplate[] } }>

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/objects#repository
-- https://docs.github.com/en/graphql/reference/objects#issuetemplate
-- https://docs.github.com/en/graphql/reference/objects#pullrequesttemplate
M.repository_templates_query = [[
query {
  repository(owner: "%s", name: "%s") {
    issueTemplates { body about name title  }
    pullRequestTemplates { body filename }
  }
}
]]

---@class BriefIssue
---@field __typename "Issue"
---@field number integer
---@field title string
---@field url string
---@field repository { nameWithOwner: string }

---@alias IssuesQueryResponse GraphQLResponse<{ repository: { issues: { nodes: BriefIssue[] }, pageInfo: PageInfo } }>

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/objects#issue
-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/input-objects#issueorder
-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/input-objects#issuefilters
-- filter eg: labels: ["help wanted", "bug"]
M.issues_query = [[
query($endCursor: String) {
  repository(owner: "%s", name: "%s") {
    issues(first: 100, after: $endCursor, filterBy: {%s}, orderBy: {field: %s, direction: %s}) {
      nodes {
        __typename
        number
        title
        url
        repository { nameWithOwner }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
]]

---@class BriefPullRequest
---@field __typename "PullRequest"
---@field number integer
---@field title string
---@field url string
---@field repository { nameWithOwner: string }
---@field headRefName string
---@field isDraft boolean

---@alias PullRequestsQueryResponse GraphQLResponse<{ repository: { pullRequests: { nodes: BriefPullRequest[] }, pageInfo: PageInfo } }>

M.pull_requests_query = [[
query($endCursor: String) {
  repository(owner: "%s", name: "%s") {
    pullRequests(first: 100, after: $endCursor, %s, orderBy: {field: %s, direction: %s}) {
      nodes {
        __typename
        number
        title
        url
        repository { nameWithOwner }
        headRefName
        isDraft
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
]]

---@alias SearchQueryResponse GraphQLResponse<{ search: { nodes: (BriefIssue|BriefPullRequest)[] } }>

M.search_query = [[
query {
  search(query: "%s", type: ISSUE, last: 100) {
    nodes {
      ... on Issue{
        __typename
        number
        url
        title
        repository { nameWithOwner }
      }
      ... on PullRequest {
        __typename
        number
        title
        url
        repository { nameWithOwner }
      }
    }
  }
}
]]

---@class ProjectColumn
---@field id string
---@field name string

---@class Project
---@field id string
---@field name string
---@field columns { nodes: ProjectColumn }

---@alias ProjectsQueryResponse GraphQLResponse<{ repository: { projects: { nodes: Project[] } }, user: { projects: { nodes: Project[] } }, organization: { projects: { nodes: Project[] } } }>

-- https://docs.github.com/en/graphql/reference/objects#project
M.projects_query = [[
query {
  repository(owner: "%s", name: "%s") {
    projects(first: 100) {
      nodes {
        id
        name
        columns(first:100) {
          nodes {
            id
            name
          }
        }
      }
    }
  }
  user(login: "%s") {
    projects(first: 100) {
      nodes {
        id
        name
        columns(first:100) {
          nodes {
            id
            name
          }
        }
      }
    }
  }
  organization(login: "%s") {
    projects(first: 100) {
      nodes {
        id
        name
        columns(first:100) {
          nodes {
            id
            name
          }
        }
      }
    }
  }
}
]]

-- https://docs.github.com/en/graphql/reference/mutations#addprojectcard
M.add_project_card_mutation = [[
  mutation {
    addProjectCard(input: {contentId: "%s", projectColumnId: "%s"}) {
      cardEdge {
        node {
          id
        }
      }
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#moveprojectcard
M.move_project_card_mutation = [[
  mutation {
    moveProjectCard(input: {cardId: "%s", columnId: "%s"}) {
      cardEdge {
        node {
          id
        }
      }
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#deleteprojectcard
M.delete_project_card_mutation = [[
  mutation {
    deleteProjectCard(input: {cardId: "%s"}) {
      deletedCardId
    }
  }
]]

---@class ProjectV2
---@field id string
---@field title string
---@field url string
---@field closed boolean
---@field number integer
---@field owner { login: string }
---@field columns { id: string, options: { id: string, name: string } }

---@alias ProjectsQueryV2Response GraphQLResponse<{ repository: { projects: { nodes: ProjectV2[] } }, user: { projects: { nodes: ProjectV2[] } }, organization: { projects: { nodes: ProjectV2[] } } }>

-- https://docs.github.com/en/graphql/reference/objects#projectv2
M.projects_query_v2 = [[
query {
  repository(owner: "%s", name: "%s") {
    projects: projectsV2(first: 100) {
      nodes {
        id
        title
        url
        closed
        number
        owner {
          ... on User {
            login
          }
          ... on Organization {
            login
          }
        }
        columns: field(name: "Status") {
          ... on ProjectV2SingleSelectField {
            id
            options {
              id
              name
            }
          }
        }
      }
    }
  }
  user(login: "%s") {
    projects: projectsV2(first: 100) {
      nodes {
        id
        title
        url
        closed
        number
        owner {
          ... on User {
            login
          }
          ... on Organization {
            login
          }
        }
        columns: field(name: "Status") {
          ... on ProjectV2SingleSelectField {
            id
            options {
              id
              name
            }
          }
        }
      }
    }
  }
  organization(login: "%s") {
    projects: projectsV2(first: 100) {
      nodes {
        id
        title
        url
        closed
        number
        owner {
          ... on User {
            login
          }
          ... on Organization {
            login
          }
        }
        columns: field(name: "Status") {
          ... on ProjectV2SingleSelectField {
            id
            options {
              id
              name
            }
          }
        }
      }
    }
  }
}
]]

-- https://docs.github.com/en/graphql/reference/mutations#addprojectv2itembyid
M.add_project_v2_item_mutation = [[
  mutation {
    addProjectV2ItemById(input: {contentId: "%s", projectId: "%s"}) {
      item {
        id
      }
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#updateprojectv2itemfieldvalue
M.update_project_v2_item_mutation = [[
  mutation {
    updateProjectV2ItemFieldValue(
      input: {
        projectId: "%s",
        itemId: "%s",
        fieldId: "%s",
        value: { singleSelectOptionId: "%s" }
      }
    ) {
      projectV2Item {
        id
      }
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#deleteprojectv2item
M.delete_project_v2_item_mutation = [[
  mutation {
    deleteProjectV2Item(input: {projectId: "%s", itemId: "%s"}) {
      deletedItemId
    }
  }
]]

---@alias CreateLabelMutationResponse GraphQLResponse<{ createLabel: { label: { id: string, name: string } } }>

-- https://docs.github.com/en/graphql/reference/mutations#createlabel
-- requires application/vnd.github.bane-preview+json
M.create_label_mutation = [[
  mutation {
    createLabel(input: {repositoryId: "%s", name: "%s", description: "%s", color: "%s"}) {
      label {
        id
        name
      }
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#removelabelsfromlabelable
M.add_labels_mutation = [[
  mutation {
    addLabelsToLabelable(input: {labelableId: "%s", labelIds: ["%s"]}) {
      labelable {
        ... on Issue {
          id
        }
        ... on PullRequest {
          id
        }
      }
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#removelabelsfromlabelable
M.remove_labels_mutation = [[
  mutation {
    removeLabelsFromLabelable(input: {labelableId: "%s", labelIds: ["%s"]}) {
      labelable {
        ... on Issue {
          id
        }
        ... on PullRequest {
          id
        }
      }
    }
  }
]]

---@class LabelWithId: Label
---@field id string

---@alias LabelsQeuryResponse GraphQLResponse<{ repository: { labels: { nodes: LabelWithId[] } } }>

-- https://docs.github.com/en/graphql/reference/objects#label
M.labels_query = [[
  query {
    repository(owner: "%s", name: "%s") {
      labels(first: 100) {
        nodes {
          id
          name
          color
        }
      }
    }
  }
]]

M.issue_labels_query = [[
  query {
    repository(owner: "%s", name: "%s") {
      issue(number: %d) {
        labels(first: 100) {
          nodes {
            id
            name
            color
          }
        }
      }
    }
  }
]]

M.pull_request_labels_query = [[
  query {
    repository(owner: "%s", name: "%s") {
      pullRequest(number: %d) {
        labels(first: 100) {
          nodes {
            id
            name
            color
          }
        }
      }
    }
  }
]]

---@alias IssueAssigneesQueryResponse GraphQLResponse<{ repository: { issue: { assignees: { nodes: User[] } } } }>

M.issue_assignees_query = [[
  query {
    repository(owner: "%s", name: "%s") {
      issue(number: %d) {
        assignees(first: 100) {
          nodes {
            id
            login
            isViewer
          }
        }
      }
    }
  }
]]

---@alias PullRequestAssigneesQueryResponse GraphQLResponse<{ repository: { pullRequest: { assignees: { nodes: User[] } } } }>

M.pull_request_assignees_query = [[
  query {
    repository(owner: "%s", name: "%s") {
      pullRequest(number: %d) {
        assignees(first: 100) {
          nodes {
            id
            login
            isViewer
          }
        }
      }
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#addassigneestoassignable
M.add_assignees_mutation = [[
  mutation {
    addAssigneesToAssignable(input: {assignableId: "%s", assigneeIds: ["%s"]}) {
      assignable {
        ... on Issue {
          id
        }
        ... on PullRequest {
          id
        }
      }
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#removeassigneestoassignable
M.remove_assignees_mutation = [[
  mutation {
    removeAssigneesFromAssignable(input: {assignableId: "%s", assigneeIds: ["%s"]}) {
      assignable {
        ... on Issue {
          id
        }
        ... on PullRequest {
          id
        }
      }
    }
  }
]]

-- https://docs.github.com/en/graphql/reference/mutations#requestreviews
-- for teams use `teamIds`
M.request_reviews_mutation = [[
  mutation {
    requestReviews(input: {pullRequestId: "%s", union: true, userIds: ["%s"]}) {
      pullRequest {
        id
        reviewRequests(first: 100) {
          nodes {
            requestedReviewer {
              ... on User {
                login
                isViewer
              }
              ... on Mannequin { login }
              ... on Team { name }
            }
          }
        }
      }
    }
  }
]]

---@class UserProfile
---@field login string
---@field bio string?
---@field company string?
---@field followers { totalCount: integer }
---@field following { totalCount: integer }
---@field hovercard { contexts: { message: string } }
---@field hasSponsorsListing boolean
---@field isEmployee boolean
---@field isViewer boolean
---@field location string?
---@field organizations { nodes: { name: string? }[] }
---@field name string?
---@field status { emoji: string?, message: string? }?
---@field twitterUsername string?
---@field websiteUrl string?

---@alias UserProfileQueryResponse GraphQLResponse<{ user: UserProfile }>

M.user_profile_query = [[
query {
  user(login: "%s") {
    login
    bio
    company
    followers(first: 1) {
      totalCount
    }
    following(first: 1) {
      totalCount
    }
    hovercard {
      contexts {
        message
      }
    }
    hasSponsorsListing
    isEmployee
    isViewer
    location
    organizations(last: 5) {
      nodes {
        name
      }
    }
    name
    status {
      emoji
      message
    }
    twitterUsername
    websiteUrl
  }
}
]]

M.changed_files_query = [[
query($endCursor: String) {
  repository(owner: "%s", name: "%s") {
    pullRequest(number: %d) {
      files(first:100, after: $endCursor) {
        nodes {
          additions
          deletions
          path
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }
}
]]

---@alias FileContentQueryResponse GraphQLResponse<{ repository: { object: { text: string? }? } }>

M.file_content_query = [[
query {
  repository(owner: "%s", name: "%s") {
    object(expression: "%s:%s") {
      ... on Blob {
        text
      }
    }
  }
}
]]

---@class ReactionGroupForObject
---@field content ReactionContent
---@field users { nodes: { login: string }[] }

---@alias ReactionsForObjectQueryResponse GraphQLResponse<{ node: { reactionGroups: ReactionGroupForObject[] } }>

M.reactions_for_object_query = [[
query {
  node(id: "%s") {
    ... on Issue {
      reactionGroups {
        content
        users(last: 100) {
          nodes {
            login
          }
        }
      }
    }
    ... on PullRequest {
      reactionGroups {
        content
        users(last: 100) {
          nodes {
            login
          }
        }
      }
    }
    ... on PullRequestReviewComment {
      reactionGroups {
        content
        users(last: 100) {
          nodes {
            login
          }
        }
      }
    }
    ... on PullRequestReview {
      reactionGroups {
        content
        users(last: 100) {
          nodes {
            login
          }
        }
      }
    }
    ... on IssueComment {
      reactionGroups {
        content
        users(last: 100) {
          nodes {
            login
          }
        }
      }
    }
  }
}
]]

---@class User
---@field id string
---@field login string
---@field isViewer boolean?

---@class Team
---@field id string
---@field name string

---@alias UsersQueryResponse GraphQLResponse<{ repository: { assignableUsers: { nodes: User[] } } }>

M.users_query = [[
query($endCursor: String) {
  repository(owner: "%s", name: "%s") {
    assignableUsers(first: 100, after: $endCursor) {
      nodes {
        id
        login
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
]]

---@class BriefRepository
---@field nameWithOwner string
---@field description string?
---@field forkCount integer
---@field stargazerCount integer
---@field isFork boolean
---@field isPrivate boolean
---@field url string

---@alias ReposQueryResponse GraphQLResponse<{ repositoryOwner: { repositories: { nodes: BriefRepository } } }>

M.repos_query = [[
query($endCursor: String) {
  repositoryOwner(login: "%s") {
    repositories(first: 10, after: $endCursor, ownerAffiliations: [COLLABORATOR, ORGANIZATION_MEMBER, OWNER]) {
      nodes {
        nameWithOwner
        description
        forkCount
        stargazerCount
        isFork
        isPrivate
        url
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
]]

---@class Repository
---@field id string
---@field nameWithOwner string
---@field description string?
---@field forkCount integer
---@field stargazerCount integer
---@field diskUsage integer?
---@field createdAt string
---@field updatedAt string
---@field pushedAt string?
---@field isFork boolean
---@field defaultBranchRef { name: string }
---@field parent { nameWithOwner: string }
---@field isArchived boolean
---@field isDisabled boolean
---@field isPrivate boolean
---@field isEmpty boolean
---@field isInOrganization boolean
---@field isSecurityPolicyEnabled boolean?
---@field securityPolicyUrl string?
---@field url string
---@field isLocked boolean
---@field lockReason "BILLING"|"MIGRATING"|"MOVING"|"RENAME"|"TRADE_RESTRICTION"|"TRANSFERRING_OWNERSHIP"
---@field isMirror boolean
---@field mirrorUrl string?
---@field hasProjectsEnabled boolean
---@field projectsUrl string
---@field homepageUrl string?
---@field primaryLanguage { name: string, color: string? }
---@field refs { nodes: { name: string }[] }
---@field languages { nodes: { name: string, color: string? }[] }


---@alias RepositoryQueryResponse GraphQLResponse<{ repository: Repository }>

M.repository_query = [[
query {
  repository(owner: "%s", name: "%s") {
    id
    nameWithOwner
    description
    forkCount
    stargazerCount
    diskUsage
    createdAt
    updatedAt
    pushedAt
    isFork
    defaultBranchRef {
      name
    }
    parent {
      nameWithOwner
    }
    isArchived
    isDisabled
    isPrivate
    isEmpty
    isInOrganization
    isSecurityPolicyEnabled
    securityPolicyUrl
    url
    isLocked
    lockReason
    isMirror
    mirrorUrl
    hasProjectsEnabled
    projectsUrl
    homepageUrl
    primaryLanguage {
      name
      color
    }
    refs(last:100, refPrefix: "refs/heads/") {
      nodes {
        name
      }
    }
    languages(first:100) {
      nodes {
        name
        color
      }
    }
  }
}
]]

---@class GistFile
---@field encodedName string?
---@field encoding string?
---@field extension string?
---@field name string?
---@field size integer?
---@field text string?

---@class Gist
---@field name string
---@field isPublic boolean
---@field isFork boolean
---@field description string?
---@field createdAt string
---@field files GistFile[]?

---@alias GistsQueryResponse GraphQLResponse<{ viewer: { gists: { nodes: Gist[], pageInfo: PageInfo } } }>

M.gists_query = [[
query($endCursor: String) {
  viewer {
    gists(first: 100, privacy: %s, after: $endCursor) {
      nodes {
        name
        isPublic
        isFork
        description
        createdAt
        files {
          encodedName
          encoding
          extension
          name
          size
          text
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
]]

---@alias CreatePrMutationResponse GraphQLResponse<{ createPullRequest: { pullRequest: PullRequestWithReviewThreads } }>

-- https://docs.github.com/en/graphql/reference/mutations#createpullrequest
M.create_pr_mutation = [[
  mutation {
    createPullRequest(input: {baseRefName: "%s", headRefName: "%s", repositoryId: "%s", title: "%s", body: "%s", draft: %s}) {
      pullRequest {
        id
        isDraft
        number
        state
        title
        body
        createdAt
        closedAt
        updatedAt
        url
        files(first:100) {
          nodes {
            path
            viewerViewedState
          }
        }
        merged
        mergedBy {
          ... on Organization { name }
          ... on Bot { login }
          ... on User {
            login
            isViewer
          }
          ... on Mannequin { login }
        }
        participants(first:10) {
          nodes {
            login
          }
        }
        additions
        deletions
        commits {
          totalCount
        }
        changedFiles
        headRefName
        headRefOid
        baseRefName
        baseRefOid
        baseRepository {
          name
          nameWithOwner
        }
        milestone {
          title
          state
        }
        author {
          login
        }
        viewerDidAuthor
        viewerCanUpdate
        reactionGroups {
          content
          viewerHasReacted
          users {
            totalCount
          }
        }
        projectCards(last: 20) {
          nodes {
            id
            state
            column {
              name
            }
            project {
              name
            }
          }
        }
        timelineItems(first: 100) {
          nodes {
            __typename
            ... on LabeledEvent {
              actor {
                login
              }
              createdAt
              label {
                color
                name
              }
            }
            ... on UnlabeledEvent {
              actor {
                login
              }
              createdAt
              label {
                color
                name
              }
            }
            ... on AssignedEvent {
              actor {
                login
              }
              assignee {
                ... on Organization { name }
                ... on Bot { login }
                ... on User {
                  login
                  isViewer
                }
                ... on Mannequin { login }
              }
              createdAt
            }
            ... on PullRequestCommit {
              commit {
                messageHeadline
                committedDate
                oid
                abbreviatedOid
                changedFiles
                additions
                deletions
                committer {
                  user {
                    login
                  }
                }
              }
            }
            ... on MergedEvent {
              createdAt
              actor {
                login
              }
              commit {
                oid
                abbreviatedOid
              }
              mergeRefName
            }
            ... on ClosedEvent {
              createdAt
              actor {
                login
              }
            }
            ... on ReopenedEvent {
              createdAt
              actor {
                login
              }
            }
            ... on ReviewRequestedEvent {
              createdAt
              actor {
                login
              }
              requestedReviewer {
                ... on User {
                  login
                  isViewer
                }
                ... on Mannequin { login }
                ... on Team { name }
              }
            }
            ... on ReviewRequestRemovedEvent {
              createdAt
              actor {
                login
              }
              requestedReviewer {
                ... on User {
                  login
                  isViewer
                }
                ... on Mannequin {
                  login
                }
                ... on Team {
                  name
                }
              }
            }
            ... on ReviewDismissedEvent {
              createdAt
              actor {
                login
              }
              dismissalMessage
            }
            ... on IssueComment {
              id
              body
              createdAt
              reactionGroups {
                content
                viewerHasReacted
                users {
                  totalCount
                }
              }
              author {
                login
              }
              viewerDidAuthor
              viewerCanUpdate
              viewerCanDelete
            }
            ... on PullRequestReview {
              id
              body
              createdAt
              viewerCanUpdate
              viewerCanDelete
              reactionGroups {
                content
                viewerHasReacted
                users {
                  totalCount
                }
              }
              author {
                login
              }
              viewerDidAuthor
              state
              comments(last:100) {
                totalCount
                nodes{
                  id
                  url
                  replyTo { id url }
                  body
                  commit {
                    oid
                    abbreviatedOid
                  }
                  author { login }
                  createdAt
                  lastEditedAt
                  authorAssociation
                  viewerDidAuthor
                  viewerCanUpdate
                  viewerCanDelete
                  originalPosition
                  position
                  state
                  outdated
                  diffHunk
                  reactionGroups {
                    content
                    viewerHasReacted
                    users {
                      totalCount
                    }
                  }
                }
              }
            }
          }
        }
        reviewDecision
        reviewThreads(last:100) {
          nodes {
            id
            isResolved
            isCollapsed
            isOutdated
            path
            resolvedBy { login }
            line
            originalLine
            startLine
            originalStartLine
            diffSide
            subjectType
            comments(first: 100) {
              nodes{
                id
                body
                createdAt
                lastEditedAt
                url
                replyTo { id url }
                state
                originalCommit {
                  oid
                  abbreviatedOid
                }
                pullRequestReview {
                  id
                  state
                }
                path
                subjectType
                author { login }
                authorAssociation
                viewerDidAuthor
                viewerCanUpdate
                viewerCanDelete
                outdated
                diffHunk
                reactionGroups {
                  content
                  viewerHasReacted
                  users {
                    totalCount
                  }
                }
              }
            }
          }
        }
        labels(first: 20) {
          nodes {
            color
            name
          }
        }
        assignees(first: 20) {
          nodes {
            id
            login
            isViewer
          }
        }
        reviewRequests(first: 20) {
          totalCount
          nodes {
            requestedReviewer {
              ... on User {
                login
                isViewer
              }
              ... on Mannequin { login }
              ... on Team { name }
            }
          }
        }
      }
    }
  }
]]

---@alias UserQueryResponse GraphQLResponse<{ user: { id: string } }>

-- https://docs.github.com/en/graphql/reference/queries#user
M.user_query = [[
query {
  user(login:"%s") {
    id
  }
}
]]

---@alias RepoLablesQueryResponse GraphQLResponse<{ repository: { labels: { nodes: { id: string, name: string }[] } } }>

-- https://docs.github.com/en/graphql/reference/objects#pullrequestreviewthread
M.repo_labels_query = [[
query {
  repository(owner:"%s", name:"%s") {
    labels(first: 100) {
      nodes {
        id
        name
      }
    }
  }
}
]]

local function escape_char(string)
  local escaped, _ = string.gsub(string, '["\n\\]', {
    ['"'] = '\\"',
    ["\\"] = "\\\\",
    ["\n"] = "\\n",
  })
  return escaped
end

return function(query, ...)
  local opts = { escape = true }
  for _, v in ipairs { ... } do
    if type(v) == "table" then
      opts = vim.tbl_deep_extend("force", opts, v)
      break
    end
  end
  local escaped = {}
  for _, v in ipairs { ... } do
    if type(v) == "string" and opts.escape then
      local encoded = escape_char(v)
      table.insert(escaped, encoded)
    else
      table.insert(escaped, v)
    end
  end
  return string.format(M[query], unpack(escaped))
end
