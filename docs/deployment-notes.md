# Deployment Notes

## Required Azure DevOps Setup

- Service connection with permission to deploy to the target resource groups.
- Variable groups named `devgroup`, `qagroup` and `prodgroup`.
- Variables in each group:
  - `DataFactory`
  - `ResourceGroup`
  - `SubscriptionId`
- Azure DevOps Environment named `prod` with approval checks configured.

## Release Safety

- Use incremental ARM deployments for normal Data Factory updates.
- Stop triggers before deployment to prevent in-flight schedules from colliding with changed definitions.
- Restart triggers only after a successful deployment.
- Keep secrets in Key Vault or Azure DevOps secure variables, not in JSON parameter files.
