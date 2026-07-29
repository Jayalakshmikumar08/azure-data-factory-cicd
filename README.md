[![Board Status](https://dev.azure.com/bujji94s94/fce1e7c5-8656-4fa1-9ee9-afae686db1ce/89b0d1ab-7658-4f84-ac6a-ba3babbf129c/_apis/work/boardbadge/3972809d-b44d-40f2-9ecd-174e4b3edbd9)](https://dev.azure.com/bujji94s94/fce1e7c5-8656-4fa1-9ee9-afae686db1ce/_boards/board/t/89b0d1ab-7658-4f84-ac6a-ba3babbf129c/Microsoft.RequirementCategory)
# Azure Data Factory CI/CD

Portfolio project by Jayalakshmi Kumar.

## Architecture

This repository separates platform provisioning from ADF application promotion into two independently runnable Azure DevOps YAML pipelines.

1. **Infrastructure pipeline** — runs after a merge to `main` and provisions the complete DEV, TEST, PREPROD and PROD platform inside existing resource groups using resource-group-scoped, modular Bicep.
2. **ADF application pipeline** — starts automatically only after the infrastructure pipeline succeeds, validates and exports ADF source once, then promotes the immutable ARM artifact through the four provisioned environments.

The completion trigger enforces infrastructure-first ordering. Both production deployment jobs use the shared `prod` Azure DevOps Environment and its approval check.

![Azure Data Factory infrastructure and application deployment architecture](docs/adf-deployment-architecture.svg)

## Infrastructure Layer

The `/devops/infrastructure-pipeline.yml` pipeline is triggered by changes merged to `main` and deploys into each existing environment resource group:

- Azure Data Factory with a system-assigned managed identity
- ADLS Gen2 storage account
- Private `landing` container
- Documented storage RBAC handoff for the separate access-management team

Infrastructure is deployed with Bicep in incremental mode. The PROD infrastructure stage uses the `prod` Azure DevOps Environment for approval checks.

`/infra/main.bicep` is the resource-group-scoped orchestration template. Focused modules under `/infra/modules` own Data Factory and storage resources. The pipeline does not register providers, create resource groups or manage role assignments.

## ADF Application Layer

The `/devops/application-pipeline.yml` pipeline:

1. Starts after the Azure DevOps pipeline named `ADF Infrastructure` completes successfully for `main`.
2. Installs Node.js and restores the locked npm dependencies.
3. Validates all checked-in ADF resources.
4. Exports an ARM artifact with Microsoft's ADF publishing utility.
5. Promotes the same artifact through DEV, TEST, PREPROD and PROD.
6. Stops changed triggers before deployment and restarts them afterward.
7. Uses the `prod` Azure DevOps Environment for production approval.

The included sample workload copies a public CSV file from GitHub into the provisioned ADLS Gen2 `landing` container. Its daily trigger is committed in the stopped state.

## Repository Structure

```text
adf/                                ADF Studio source root
  factory/                          Development factory definition
  linkedService/                    HTTP and ADLS linked services
  dataset/                          Source and destination datasets
  pipeline/                         Sample copy pipeline
  trigger/                          Stopped schedule trigger
  arm-template-parameters-definition.json
  publish_config.json
infra/                              Bicep infrastructure layer
  main.bicep                        Resource-group entry point
  modules/                          Focused resource modules
    data-factory.bicep              Factory and managed identity
    storage.bicep                   ADLS Gen2 and landing container
devops/                             Both Azure DevOps pipelines
  infrastructure-pipeline.yml
  application-pipeline.yml
  pipeline-variables.yml            Shared compile-time pipeline configuration
  templates/                        Reusable build/deployment steps
  parameters/                       Environment ARM parameters
docs/                               Diagram and deployment runbook
  rbac-handoff.md                   Separate-team storage access procedure
package.json                        ADF build tooling
```

Generated directories such as `node_modules/`, `downloads/` and `ArmTemplate/` are ignored and are not committed.

## Why Node.js Is Required

Node.js is required only by the ADF application CI build. Microsoft distributes the automated ADF validation and publishing utility as the `@microsoft/azure-data-factory-utilities` npm package.

The utility validates pipelines, datasets, linked services and triggers, then exports them into the ARM artifact promoted across environments. Node.js is installed temporarily on the hosted build agent and is not deployed to Azure Data Factory.

Node.js is not used by the infrastructure pipeline; Azure Resource Manager compiles and deploys the Bicep files.

## Deployment Order

1. Configure the Azure service connections, variable groups and approval environment described in [Deployment Notes](docs/deployment-notes.md).
2. Create the infrastructure pipeline with the exact name `ADF Infrastructure`.
3. Create the application pipeline, then merge a change to `main`.
4. Approve the PROD infrastructure deployment when the run reaches the `prod` Environment.
5. Confirm the application pipeline starts after infrastructure succeeds.
6. Approve the PROD application deployment when the run reaches `prod`.
7. Validate the sample copy activity before enabling its trigger.

## Enterprise Controls Demonstrated

- Infrastructure and application lifecycle separation
- Declarative, repeatable Bicep infrastructure
- Managed identity authentication without storage keys
- Least-purpose data-plane RBAC handoff with separated access-management duties
- Immutable ADF artifact promotion
- Environment-specific configuration without committed secrets
- Incremental deployments
- Trigger-safe ADF releases
- Shared `prod` Environment approval protection for infrastructure and application deployments.
