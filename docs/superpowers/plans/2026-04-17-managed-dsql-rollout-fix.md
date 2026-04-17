# Managed DSQL Rollout Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the shared rollout workflow redeploy stack configuration after managed DSQL endpoint reconciliation so Lambda environment variables pick up `DSQL_ENDPOINT` without requiring a separate follow-up deploy.

**Architecture:** Preserve the existing split where Pulumi creates the DSQL cluster and a dedicated reconcile action resolves the authoritative endpoint from AWS. Extend the shared rollout workflow to use that reconcile result immediately by performing a second apply before output capture, canaries, and refresh.

**Tech Stack:** GitHub Actions YAML, shell-based repository tests, Pulumi wrapper action

---

### Task 1: Shared Workflow Test Coverage

**Files:**
- Modify: `test/generic-workflows-test.sh`
- Test: `test/generic-workflows-test.sh`

- [ ] Add a failing assertion that requires the rollout workflow to define `reconcile_managed_dsql_endpoint` input text and a second `command: up` step after managed DSQL reconcile.
- [ ] Run `./test/generic-workflows-test.sh` and confirm it fails before workflow changes.

### Task 2: Shared Workflow Redeploy Step

**Files:**
- Modify: `.github/workflows/rollout-hop.yml`
- Test: `test/generic-workflows-test.sh`

- [ ] Add a `run-pulumi` apply step after `Reconcile managed DSQL endpoint` guarded by `inputs.reconcile_managed_dsql_endpoint`.
- [ ] Keep the new apply before output capture and canary execution so exported function metadata reflects the Lambda version that includes `DSQL_ENDPOINT`.
- [ ] Re-run `./test/generic-workflows-test.sh` and confirm it passes.

### Task 3: Focused Verification

**Files:**
- Test: `test/generic-workflows-test.sh`
- Test: `test/reconcile-managed-dsql-endpoint-test.sh`

- [ ] Run `./test/generic-workflows-test.sh`.
- [ ] Run `./test/reconcile-managed-dsql-endpoint-test.sh`.
- [ ] Confirm both pass and note that the reconcile action contract remains unchanged.
