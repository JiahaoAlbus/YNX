# 给 Copilot 的仓库操作 Prompt（2026-03-27）

状态：active  
最后更新：2026-03-27

> 使用前说明：先用 **只读规划模式**，确认步骤无误后再执行。

## 1) 只读规划版（推荐先跑）

```text
Read-only planning mode.
Do NOT execute any command.
Do NOT change repository permissions.

Context:
- Repo: YNX
- Goal: prepare audit handoff operations checklist.

Please output:
1) exact GitHub UI steps to grant read-only access to:
   - @openzeppelin-estimates
   - @vasilikigrezios-oz
   - @halbornteam
2) equivalent gh CLI commands (manual run only)
3) verification checklist to confirm permissions are correctly applied
4) rollback steps to remove external access after scoping

Keep output concise and copy-paste ready.
```

## 2) 可执行版（你确认后再用）

```text
Execution mode allowed.
Before each write action, print the command and wait for confirmation.

Context:
- Repo: YNX
- Grant read-only access for scoping only:
  @openzeppelin-estimates, @vasilikigrezios-oz, @halbornteam

Tasks:
1) Apply access changes.
2) Verify each collaborator has read-only access.
3) Print final status summary.
4) Generate rollback commands to revoke all temporary access.
```

