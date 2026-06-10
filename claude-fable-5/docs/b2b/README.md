# B2B corporate wellness licensing — deferred

Architecture is designed but implementation is **deferred** (see SPEC.md,
"Decisions Deferred"). Nothing in the v1 app depends on this directory.

What lands here when the workstream opens:

- wireframes for the corporate wellness dashboard
- API surface drafts (license provisioning, anonymized aggregate insights)
- data-sharing & privacy notes (the app stays offline; any B2B telemetry
  would be a separate, explicit opt-in product)

The v1 backup format reserves room for B2B fields; the optional backup
encryption (AES-256-GCM) already covers them.
