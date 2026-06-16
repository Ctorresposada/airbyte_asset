# Diagram assets

This folder holds the architecture and flow diagrams embedded in the documentation under `docs/`.
The diagrams are authored in **Lucid** (the editable source of truth) and exported here as PNG files.

## How the docs reference these images

Each KT document embeds an image with a relative path like `![caption](../assets/r20-<name>.png)`.
For an image to render, a PNG with the **exact filename** below must exist in this folder.

| Filename | Used by |
|----------|---------|
| `r20-platform-architecture.png` | concepts-glossary.md |
| `r20-repo-structure.png` | KT-01, Repository structure |
| `r20-local-precommit-flow.png` | KT-02, local checks and pre-commit flow |
| `r20-cicd-plan-apply-flow.png` | KT-03, CI/CD plan and apply flow |
| `r20-oidc-role-chain.png` | KT-03 and oidc_role_chain.md, OIDC role chain |
| `r20-base-bootstrap-lifecycle.png` | KT-04, base stack bootstrap lifecycle |
| `r20-troubleshooting-tree.png` | KT-05, troubleshooting decision tree |
| `r20-dbt-pr-to-dev-flow.png` | KT-06, Section 1 (PR → dev flow) — **pending export from Lucid** |
| `r20-dbt-tag-to-prod-promotion.png` | KT-06, Section 1 (tag → prod promotion flow) — **pending export from Lucid** |
| `r20-airbyte-architecture.png` | KT-07, Section 2 (Big picture / architecture) — **pending export from Lucid** |
| `r20-airbyte-access-paths.png` | KT-07, Section 3 (Networking, DNS, TLS, and access gating) — **pending export from Lucid** |
| `r20-airbyte-boot-sequence.png` | KT-07, Section 6 (EC2 bootstrap / user-data) — **pending export from Lucid** |
