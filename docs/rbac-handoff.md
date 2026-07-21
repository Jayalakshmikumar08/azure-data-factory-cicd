# Storage RBAC handoff

Storage role assignments are intentionally outside the infrastructure and ADF application pipelines. The separate team that owns Azure access management must complete this handoff for every environment.

## Required assignment

Assign the following access after the infrastructure pipeline creates the Data Factory and storage account:

| Setting   | Required value                                      |
| --------- | --------------------------------------------------- |
| Principal | Azure Data Factory system-assigned managed identity |
| Role      | `Storage Blob Data Contributor`                     |
| Scope     | Environment storage account                         |

The role definition ID for `Storage Blob Data Contributor` is `ba92f5b4-2d11-453d-a403-e96b0029c9fe`.

## Required access for the RBAC team

The person or automation creating the assignments needs one of these roles at each target storage account or its containing resource group:

- `Role Based Access Control Administrator`
- `User Access Administrator`
- `Owner`

The infrastructure and application pipeline service principals do not need these roles.

## Create the assignments

Sign in with the RBAC team's authorized identity, then run:

```powershell
az login
az account set --subscription "27dfae66-1618-414c-a9a1-b4d2c70c333e"

$environments = @(
    @{ ResourceGroup = "RG-dev"; DataFactory = "adf-ado-dev"; StorageAccount = "adfadodevst" },
    @{ ResourceGroup = "RG-Test"; DataFactory = "adf-ado-test"; StorageAccount = "adfadotestst" },
    @{ ResourceGroup = "RG-preprod"; DataFactory = "adf-ado-preprod"; StorageAccount = "adfadopreprodst" },
    @{ ResourceGroup = "RG-prod"; DataFactory = "adf-ado-prod"; StorageAccount = "adfadoprodst" }
)

foreach ($environment in $environments) {
    $principalId = az datafactory show `
        --resource-group $environment.ResourceGroup `
        --factory-name $environment.DataFactory `
        --query "identity.principalId" `
        --output tsv

    $storageAccountId = az storage account show `
        --resource-group $environment.ResourceGroup `
        --name $environment.StorageAccount `
        --query "id" `
        --output tsv

    if (-not $principalId -or -not $storageAccountId) {
        throw "Could not resolve resources in '$($environment.ResourceGroup)'."
    }

    $existingAssignmentId = az role assignment list `
        --assignee $principalId `
        --scope $storageAccountId `
        --query "[?roleDefinitionName=='Storage Blob Data Contributor'].id | [0]" `
        --output tsv

    if ($existingAssignmentId) {
        Write-Host "Storage access already exists in $($environment.ResourceGroup)"
    }
    else {
        az role assignment create `
            --assignee-object-id $principalId `
            --assignee-principal-type ServicePrincipal `
            --role "Storage Blob Data Contributor" `
            --scope $storageAccountId `
            --output none

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to assign storage access in '$($environment.ResourceGroup)'."
        }

        Write-Host "Assigned storage access in $($environment.ResourceGroup)"
    }
}
```

The script checks for the assignment before creating it, so it can be rerun safely.

## Verify the assignments

```powershell
foreach ($environment in $environments) {
    $principalId = az datafactory show `
        --resource-group $environment.ResourceGroup `
        --factory-name $environment.DataFactory `
        --query "identity.principalId" `
        --output tsv

    $storageAccountId = az storage account show `
        --resource-group $environment.ResourceGroup `
        --name $environment.StorageAccount `
        --query "id" `
        --output tsv

    az role assignment list `
        --assignee $principalId `
        --scope $storageAccountId `
        --query "[?roleDefinitionName=='Storage Blob Data Contributor'].{Principal:principalId,Role:roleDefinitionName,Scope:scope}" `
        --output table
}
```

Each environment must return one `Storage Blob Data Contributor` assignment before running or enabling ADF pipelines that write to ADLS Gen2. Allow several minutes for a new assignment to propagate.
