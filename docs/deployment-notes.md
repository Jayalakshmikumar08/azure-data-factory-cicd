# Deployment Notes

## Required Azure DevOps Setup

### Service connection

The project uses two enabled Azure Resource Manager service connections, configured once in `/devops/pipeline-variables.yml`:

- `ADF-ADO-Project-Nonprod` for DEV and TEST.
- `ADF-ADO-Project-Prod` for PREPROD and PROD.

Both pipelines import this shared compile-time configuration.

Azure DevOps authorizes protected resources before runtime macro variables and stage-scoped variable groups are expanded. For this reason, a service-connection name supplied as `$(azureServiceConnection)` by an environment variable group is not valid for these tasks.

The resource groups must already exist, and the required resource providers must already be registered. The pipeline performs no provider-registration, resource-group-creation, subscription deployment or role-assignment actions.

- `Contributor` on each target resource group to deploy Data Factory and storage resources.

No subscription-level Azure role is required by this pipeline. Limit each service connection to its intended resource groups and authorize only these two pipelines.

Storage access is owned by a separate team. After infrastructure deployment, that team must complete [Storage RBAC handoff](rbac-handoff.md) before ADF workloads write to ADLS Gen2.

### Variable groups

Create these groups:

- `devgroup`
- `testgroup`
- `preprodgroup`
- `prodgroup`

Every group must contain:

| Variable         | Purpose                                                |
| ---------------- | ------------------------------------------------------ |
| `DataFactory`    | Globally unique Data Factory name.                     |
| `ResourceGroup`  | Existing environment resource group targeted by Bicep. |
| `SubscriptionId` | Target Azure subscription ID.                          |
| `StorageAccount` | Globally unique, lowercase ADLS Gen2 account name.     |

The commands and configured names are documented in `C:\Users\workout\Desktop\Github-Projects\Scripts\create-azure-devops-variable-groups.md`.

### Approval environment

Create one Azure DevOps Environment and configure its approval check:

- `prod` — approval before both production infrastructure and production ADF application deployments.

Both production deployment jobs reference this same Environment. Azure DevOps evaluates its approval check when each job attempts to use it.

## Pipeline 1: Infrastructure

Create an Azure DevOps pipeline named exactly `ADF Infrastructure` using the existing YAML file:

```text
/devops/infrastructure-pipeline.yml
```

This pipeline has a CI trigger for `main` and no pull-request validation trigger. With a branch policy that requires pull requests, each merge to `main` automatically starts infrastructure deployment. Azure Pipelines treats a direct push to `main` the same way, so protect `main` if merge-only execution is required.

It provisions environments in this order:

```text
DEV → TEST → PREPROD → approval → PROD
```

The deployment is idempotent and incremental. Re-running it brings managed resources back to the Bicep definition without deleting unrelated resources. `infra/main.bicep` orchestrates focused modules in `infra/modules` for Data Factory, storage and RBAC.

Infrastructure outputs include the factory name, managed-identity principal ID and storage DFS endpoint. The shared variable groups provide the same names to the application pipeline.

## Pipeline 2: ADF Application

Create a second Azure DevOps pipeline using:

```text
/devops/application-pipeline.yml
```

This pipeline has no direct Git trigger. Its pipeline-resource completion trigger starts it automatically after the `ADF Infrastructure` pipeline succeeds for `main`. Because PROD infrastructure is part of that upstream run, the application pipeline starts only after its infrastructure approval and successful PROD deployment.

Its stages are:

```text
Build ADF artifact → DEV → TEST → PREPROD → approval → PROD
```

The build exports these files into the `ArmTemplate` pipeline artifact:

- `ARMTemplateForFactory.json`
- `ARMTemplateParametersForFactory.json`
- `PrePostDeploymentScript.ps1`
- Linked deployment templates and generated helper files

The deployment template does not create or modify platform infrastructure. It deploys only ADF child resources such as pipelines, datasets, linked services and triggers.

## Environment Configuration

| Environment | Data Factory      | Storage account   |
| ----------- | ----------------- | ----------------- |
| DEV         | `adf-ado-dev`     | `adfadodevst`     |
| TEST        | `adf-ado-test`    | `adfadotestst`    |
| PREPROD     | `adf-ado-preprod` | `adfadopreprodst` |
| PROD        | `adf-ado-prod`    | `adfadoprodst`    |

Data Factory and Storage account names are globally unique. Change a name consistently in its variable group and ARM parameter file if Azure reports that it is unavailable.

## Why Node.js Is Used

Node.js is a build-time dependency only in the ADF application pipeline. It runs Microsoft's `@microsoft/azure-data-factory-utilities` package to validate the ADF source JSON and export the deployable ARM artifact.

`UseNode@1` installs Node.js 22 on the hosted agent, and `npm ci` restores the exact dependency versions in `package-lock.json`. Node.js is not part of the deployed Azure infrastructure or ADF runtime.

## First Run Checklist

1. Confirm the required resource providers are registered: `Microsoft.DataFactory`, `Microsoft.Storage` and `Microsoft.Authorization`.
2. Create or update all four variable groups.
3. Configure the approval check on the `prod` Environment.
4. Create the infrastructure pipeline with the exact name `ADF Infrastructure`.
5. Create the application pipeline from `/devops/application-pipeline.yml`.
6. Merge a change to `main` and confirm the infrastructure pipeline starts.
7. Approve the infrastructure deployment at the `prod` Environment and confirm all four infrastructure stages succeed.
8. Confirm the application pipeline starts automatically after that success.
9. Confirm every Data Factory has a system-assigned identity.
10. Confirm each storage account contains the `landing` container.
11. Obtain confirmation from the RBAC team that the Data Factory identity has Storage Blob Data Contributor on its storage account.
12. Approve the application deployment at the `prod` Environment.
13. Test `pl_ingest_github_csv` manually in DEV.
14. Enable `tr_daily_ingest` only after the manual test succeeds.

## Release Safety

- Review Bicep what-if results before material infrastructure changes.
- Protect both production deployment jobs with the shared `prod` Environment approval check.
- Use incremental deployments.
- Never store storage keys or service-principal secrets in Git.
- Stop changed triggers before ADF deployment.
- If an ADF deployment fails after triggers stop, inspect and restart the intended triggers manually after correcting the deployment.
