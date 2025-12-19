metadata description = 'Creates an Azure AI Search instance.'
param name string
param location string = resourceGroup().location
param tags object = {}
param projectName string
param serviceName string
param sku object = {
  name: 'standard'
}

param authOptions object = {}
param disableLocalAuth bool = false
param disabledDataExfiltrationOptions array = []
param encryptionWithCmk object = {
  enforcement: 'Unspecified'
}
@allowed([
  'default'
  'highDensity'
])
param hostingMode string = 'default'
param networkRuleSet object = {
  bypass: 'None'
  ipRules: []
}
param partitionCount int = 1
@allowed([
  'enabled'
  'disabled'
])
param publicNetworkAccess string = 'enabled'
param replicaCount int = 1
@allowed([
  'disabled'
  'free'
  'standard'
])
param semanticSearch string = 'disabled'

var searchIdentityProvider = (sku.name == 'free') ? null : {
  type: 'SystemAssigned'
}




resource search 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'basic'
  }
  identity: searchIdentityProvider
  properties: {
    authOptions: authOptions
    disableLocalAuth: disableLocalAuth
    disabledDataExfiltrationOptions: disabledDataExfiltrationOptions
    encryptionWithCmk: encryptionWithCmk
    hostingMode: hostingMode
    networkRuleSet: networkRuleSet
    partitionCount: partitionCount
    publicNetworkAccess: publicNetworkAccess
    replicaCount: replicaCount
    semanticSearch: semanticSearch
  }
}

module aiSearchCognitiveServicesUser  '../security/role.bicep' = {
  name: 'aisearch-role-cognitive-services-user'
  scope: resourceGroup()
  params: {
    principalType: 'ServicePrincipal'
    principalId: search.identity.principalId
    roleDefinitionId: 'a97b65f3-24c7-4388-baec-2e87135dc908'
  }
}

// Grant the AI Foundry project identity access to query/index Azure AI Search when using AAD auth
resource aiProjectSearchIndexDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, projectName, '8ebe5a00-799e-43f5-93ac-243d3dce84a7')
  scope: search
  properties: {
    principalId: aiServices::project.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7') // Search Index Data Contributor
  }
}

resource aiServices 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: serviceName

  resource project 'projects' existing = {
    name: projectName

    // AI Project Search Connection
    resource searchConnectionApiKey 'connections' = if (!disableLocalAuth) {
      name: 'searchConnection'
      properties: {
        category: 'CognitiveSearch'
        authType: 'ApiKey'
        isSharedToAll: true
        target: 'https://${search.name}.search.windows.net/'
        credentials: {
          key: search.listAdminKeys().primaryKey
        }
      }
    }

    resource searchConnectionAad 'connections' = if (disableLocalAuth) {
      name: 'searchConnection'
      properties: {
        category: 'CognitiveSearch'
        authType: 'AAD'
        isSharedToAll: true
        target: 'https://${search.name}.search.windows.net/'
      }
    }

  }
}


output id string = search.id
output endpoint string = 'https://${name}.search.windows.net/'
output name string = search.name
output principalId string = !empty(searchIdentityProvider) ? search.identity.principalId : ''
output searchConnectionId string = !empty(searchIdentityProvider)
  ? (disableLocalAuth ? aiServices::project::searchConnectionAad.id : aiServices::project::searchConnectionApiKey.id)
  : ''

