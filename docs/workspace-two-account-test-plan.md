# Venturify collaboration workspace two-account test

Use two separate verified accounts, A and B, and a third unrelated account C.

## Collaboration lifecycle
1. A sends B a collaboration request.
2. Confirm neither account can access a workspace before acceptance.
3. B accepts; both can open the same workspace.
4. B declines or the request is no longer accepted in a disposable test setup; confirm workspace content is no longer accessible.

## Workspace permissions
- A and B can read project chat, tasks, checklist items, comments, milestones, and shared files.
- C cannot read any workspace rows, messages, signed file URLs, or storage objects.
- Attempts to send a message as another user fail.
- Attempts to change task/checklist/comment/milestone identity, creator, or workspace/task association fail.
- Valid title/content/status/date edits still work for permitted fields.

## File storage
- Upload a new file, download it as A and B, and verify C is denied.
- Replace an owned file using upsert and confirm the update succeeds for an accepted collaborator where permitted.
- Attempt a path using another workspace UUID; verify denial.
- Verify rejected/withdrawn collaboration no longer grants file access.

## Notifications and realtime
- Send a chat message and confirm the recipient gets one notification, not duplicates.
- Verify both collaborators receive permitted realtime updates.
- Trigger a near-deadline task and confirm only the workspace collaborator receives the deadline notification.

## Evidence to record
For each check, record account role, action, expected result, actual result, and browser console/network errors. Do not mark a test passed without observing the result in both sessions.
