targetScope = 'resourceGroup'

@description('Short environment name used for resource tags and deployment naming.')
@allowed([
  'dev'
  'test'
  'preprod'
  'prod'
])
param environmentName string

@description('Azure region for all environment resources.')
param location string = 'uksouth'

@description('Globally unique Azure Data Factory name.')
param dataFactoryName string

@description('Globally unique ADLS Gen2 storage account name.')
@minLength(3)
@maxLength(24)
param storageAccountName string

var commonTags = {
  application: 'azure-data-factory-cicd'
  environment: environmentName
  managedBy: 'bicep'
}

module storage 'modules/storage.bicep' = {
  name: 'storage-${environmentName}'
  params: {
    location: location
    storageAccountName: storageAccountName
    tags: commonTags
  }
}

module dataFactory 'modules/data-factory.bicep' = {
  name: 'data-factory-${environmentName}'
  params: {
    dataFactoryName: dataFactoryName
    location: location
    tags: commonTags
  }
}

output resourceGroupName string = resourceGroup().name
output dataFactoryName string = dataFactory.outputs.dataFactoryName
output dataFactoryPrincipalId string = dataFactory.outputs.dataFactoryPrincipalId
output storageAccountName string = storage.outputs.storageAccountName
output storageDfsEndpoint string = storage.outputs.storageDfsEndpoint
output landingContainerName string = storage.outputs.landingContainerName
