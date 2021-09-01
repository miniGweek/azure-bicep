param location string
param networkInterfaceName string
param enableAcceleratedNetworking bool
param networkSecurityGroupName string
param networkSecurityGroupRules array
param subnetName string
param virtualNetworkName string
param addressPrefixes array
param subnets array
param publicIpAddressName string
param publicIpAddressType string
param publicIpAddressSku string
param virtualMachineName string
param virtualMachineComputerName string
param virtualMachineRG string
param osDiskType string
param dataDisks array
param dataDiskResources array
param virtualMachineSize string
param adminUsername string

@secure()
param adminPassword string
param patchMode string
param enableHotpatching bool
param availabilitySetName string
param availabilitySetPlatformFaultDomainCount int
param availabilitySetPlatformUpdateDomainCount int
param autoShutdownStatus string
param autoShutdownTime string
param autoShutdownTimeZone string
param autoShutdownNotificationStatus string
param autoShutdownNotificationLocale string
param autoShutdownNotificationEmail string
param sqlVirtualMachineLocation string
param sqlVirtualMachineName string
param sqlConnectivityType string
param sqlPortNumber int
param sqlStorageDisksCount int
param sqlStorageWorkloadType string
param sqlStorageDisksConfigurationType string
param sqlStorageStartingDeviceId int
param sqlStorageDeploymentToken int
param sqlAutopatchingDayOfWeek string
param sqlAutopatchingStartHour int
param sqlAutopatchingWindowDuration int
param sqlAuthenticationLogin string

@secure()
param sqlAuthenticationPassword string
param dataPath string
param dataDisksLUNs array
param logPath string
param logDisksLUNs array
param tempDbPath string
param rServicesEnabled bool

var nsgId = networkSecurityGroupName_resource.id
var vnetId = virtualNetworkName_resource.id
var subnetRef = '${vnetId}/subnets/${subnetName}'

resource networkInterfaceName_resource 'Microsoft.Network/networkInterfaces@2018-10-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.0.0.68'
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: resourceId(resourceGroup().name, 'Microsoft.Network/publicIpAddresses', publicIpAddressName)
          }
        }
      }
    ]
    enableAcceleratedNetworking: enableAcceleratedNetworking
    networkSecurityGroup: {
      id: nsgId
    }
  }
  dependsOn: [
    networkSecurityGroupName_resource
    virtualNetworkName_resource
    publicIpAddressName_resource
  ]
}

resource networkSecurityGroupName_resource 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: networkSecurityGroupRules
  }
}

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: subnets
  }
}

resource publicIpAddressName_resource 'Microsoft.Network/publicIpAddresses@2019-02-01' = {
  name: publicIpAddressName
  location: location
  sku: {
    name: publicIpAddressSku
  }
  properties: {
    publicIPAllocationMethod: publicIpAddressType
  }
}

resource dataDiskResources_name 'Microsoft.Compute/disks@2020-12-01' = [for item in dataDiskResources: {
  name: item.name
  location: location
  sku: {
    name: item.sku
  }
  properties: item.properties
}]

resource virtualMachineName_resource 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: 'microsoftsqlserver'
        offer: 'sql2017-ws2019'
        sku: 'sqldev'
        version: 'latest'
      }
      dataDisks: [for item in dataDisks: {
        lun: item.lun
        name: item.name
        toBeDetached: item.toBeDetached
        createOption: item.createOption
        caching: item.caching
        diskSizeGB: item.diskSizeGB
        managedDisk: {
          id: (item.id ?? ((item.name == json('null')) ? json('null') : resourceId('Microsoft.Compute/disks', item.name)))
          storageAccountType: item.storageAccountType
        }
        writeAcceleratorEnabled: item.writeAcceleratorEnabled
      }]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceName_resource.id
        }
      ]
    }
    osProfile: {
      computerName: virtualMachineComputerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          enableHotpatching: enableHotpatching
          patchMode: patchMode
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    availabilitySet: {
      id: availabilitySetName_resource.id
    }
  }
  dependsOn: [
    dataDiskResources_name
  ]
}

resource availabilitySetName_resource 'Microsoft.Compute/availabilitySets@2019-07-01' = {
  name: availabilitySetName
  location: location
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformFaultDomainCount: availabilitySetPlatformFaultDomainCount
    platformUpdateDomainCount: availabilitySetPlatformUpdateDomainCount
  }
}

resource shutdown_computevm_virtualMachineName 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${virtualMachineName}'
  location: location
  properties: {
    status: autoShutdownStatus
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime
    }
    timeZoneId: autoShutdownTimeZone
    targetResourceId: virtualMachineName_resource.id
    notificationSettings: {
      status: autoShutdownNotificationStatus
      notificationLocale: autoShutdownNotificationLocale
      timeInMinutes: 30
      emailRecipient: autoShutdownNotificationEmail
    }
  }
}

resource sqlVirtualMachineName_resource 'Microsoft.SqlVirtualMachine/SqlVirtualMachines@2017-03-01-preview' = {
  name: sqlVirtualMachineName
  location: sqlVirtualMachineLocation
  properties: {
    virtualMachineResourceId: resourceId('Microsoft.Compute/virtualMachines', sqlVirtualMachineName)
    sqlImageSku: 'Developer'
    sqlManagement: 'Full'
    sqlServerLicenseType: 'PAYG'
    autoPatchingSettings: {
      dayOfWeek: 'Sunday'
      enable: true
      maintenanceWindowDuration: 60
      maintenanceWindowStartingHour: 2
    }
    keyVaultCredentialSettings: {
      enable: false
      credentialName: ''
    }
    storageConfigurationSettings: {
      diskConfigurationType: 'NEW'
      storageWorkloadType: 'OLTP'
      sqlDataSettings: {
        luns: dataDisksLUNs
        defaultFilePath: dataPath
      }
      sqlLogSettings: {
        luns: logDisksLUNs
        defaultFilePath: logPath
      }
      sqlTempDbSettings: {
        defaultFilePath: tempDbPath
      }
    }
    serverConfigurationsManagementSettings: {
      sqlConnectivityUpdateSettings: {
        connectivityType: sqlConnectivityType
        port: sqlPortNumber
        sqlAuthUpdateUserName: sqlAuthenticationLogin
        sqlAuthUpdatePassword: sqlAuthenticationPassword
      }
      additionalFeaturesServerConfigurations: {
        isRServicesEnabled: rServicesEnabled
      }
    }
  }
}

output adminUsername string = adminUsername
