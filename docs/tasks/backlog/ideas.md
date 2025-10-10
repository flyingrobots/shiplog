### What's Exemplary and What I Like

The entire **Git-native philosophy** is the standout feature. Most tools would introduce a separate database, a server process, and an API. Shiplog smartly rejects this complexity and leverages the inherent strengths of Git itself:

1.  **The Trust Model is Superb**: The combination of a signed genesis commit for the trust root, the `allowed_signers` file, and the policy-as-code JSON is a robust and transparent way to manage authority. It's an enterprise-grade security model implemented with standard Git objects, which is brilliant.
   
2.  **Graceful Degradation for UX**: The explicit design for both a rich TTY experience with `bosun` and a simple, scriptable `--boring` mode is excellent engineering. It serves human operators and CI/CD robots as equal citizens, which many tools fail to do.
   
3.  **Policy as Code**: The `policy.json` file, with its clearly defined resolution order, is powerful. Allowing teams to codify rules like "prod deployments require a ticket" or "only SREs can sign for the `prod` environment" directly in the repository is a huge win for auditable governance.

### What's Unconventional (in a good way)

1.  **Empty-Tree Commits as Database Records**: This is the most unconventional and clever part. Instead of just using tags, Shiplog creates an actual commit object for each entry. This gives every deployment record its own SHA-1 identity, a parent, a signature, and a timestamp—making it a first-class node in the Git graph. It's a perfect conceptual fit.
   
2.  **Using Git Notes for Log Payloads**: Git notes are an underutilized feature, and using them to attach potentially large log outputs is the perfect application. It keeps the primary commit object (the metadata) small and clean, while still providing a cryptographically-linked, inseparable home for the raw output.
   
3.  **The Self-Contained `bosun` Helper**: In a world of heavy dependencies, creating a lightweight, shell-native TUI helper is a refreshing choice. It preserves the tool's minimalist ethos while still providing a polished user experience.

---
### Three "Killer Feature" Ideas

Here are a few ideas that build on Shiplog's existing strengths:

1.  **"Provenance Rollback" (`git shiplog rollback`)**
    * **The Pitch**: Since Shiplog knows the exact Git SHA (`repo_head`) and the command that was run for every successful deployment, it has all the information needed to perform a rollback.
    * **How it Works**: A command like `git shiplog rollback --env prod --to <good-entry-id>` could automatically generate and execute the `run` command needed to redeploy the last known good version. It would create a new "revert" entry in the log, with a link back to the entry being rolled back, providing a complete audit trail of the incident. It turns the audit log into an actionable recovery tool.

2.  **"Timeline Diff" (`git shiplog diff --env prod --since "1 hour ago"`)**
    * **The Pitch**: During an incident, the most critical question is *"What changed?"*. This feature would answer that by looking at the deployment timeline, not just the code.
    * **How it Works**: It would analyze a range of Shiplog entries and generate a summary of changes:
        * **Artifacts**: `v1.2.3` was deployed, then `v1.2.4`.
        * **Configuration**: The deployment target changed from `cluster-a` to `cluster-b`.
        * **Behavior**: The `run` command changed from `./deploy.sh` to `./deploy-new.sh`.
        * **Logs**: It could even diff the attached notes to find new error messages between deployments.

3.  **"Shiplog Explorer" (An Interactive TUI)**
    * **The Pitch**: An interactive terminal dashboard for exploring the deployment history.
    * **How it Works**: Running `git shiplog explore` would launch a TUI built with `bosun` primitives. The left pane could be a filterable list of entries (`ls` output). Selecting an entry would display its full details (`show` output) in the right pane, including the attached log. You could navigate from an entry to its parent, find all deployments of a specific Git tag, and trace the history of a service across all environments. It would make the data you're so carefully collecting instantly accessible and navigable.
