targetScope = 'resourceGroup'

@description('Globally unique Azure Data Factory name.')
param dataFactoryName string

@description('Azure region for the Data Factory.')
param location string

@description('Common resource tags.')
param tags object

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactoryName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
  tags: tags
}

output dataFactoryName string = dataFactory.name
output dataFactoryPrincipalId string = dataFactory.identity.principalId
