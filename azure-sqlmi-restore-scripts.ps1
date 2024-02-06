########Get info about specific Azure SQL MI################################################################################################################################################
Get-AzSqlInstance -InstanceName $InstanceName -ResourceGroupName  $ResourceGroupName 
  
########Get the list of all database names for a specific Azure SQL MIMI#####################################################################################################################
$Databases = Get-AzSqlInstanceDatabase -InstanceName $InstanceName -ResourceGroupName  $ResourceGroupName
foreach($database in $Databases.Name){Write-Output  "Checking DB Name: $database"}

Get-AzSqlInstanceDatabaseBackupShortTermRetentionPolicy -ResourceGroupName $ResourceGroupName -InstanceName $InstanceName -DatabaseName "rinmardb"
#EarliestRestorePoint + RetentionDays - 7minutes


  
######## 1A Restore SINGLE database on the SAME managed instance in same SUB from PITR backup to latest/specified restore time #######################################################################
$SubscriptionId = "c0723d0a-90a1-42b0-ba86-efd217b7483e"
$InstanceName = "sqlmi-pc-db-02"
$ResourceGroupName = "rg-sqlmi-pc-db-02"
$Database="IF_SysMan"

#Set restore time (specific time UTC or latest possible time UTC). Uncomment and comment out relevant lines.
#$RestorePITRtime = "2023-06-20 08:00:00" #specify time in UTC 
#$RestorePITRtime = [datetime]"$RestorePITRtime-00:00" #convert to UTC
$RestorePITRtime=Get-Date #get current time
$RestorePITRtime=$RestorePITRtime.ToUniversalTime() #convert to UTC

Set-AzContext -SubscriptionId $SubscriptionId
Write-Host 'Target database name:' $Database"_restored"
Write-Host 'Try to get PITR backup from UTC time:' $RestorePITRtime
Restore-AzSqlInstanceDatabase -FromPointInTimeBackup -ResourceGroupName $ResourceGroupName  -InstanceName  $InstanceName `
-Name $Database -PointInTime $RestorePITRtime -TargetInstanceDatabaseName $Database"_restored"

######## 1B Restore ALL database on the SAME managed instance in same SUB from PITR backup to latest/specified restore time ###########################################################################
$SubscriptionId = "c0723d0a-90a1-42b0-ba86-efd217b7483e"
$InstanceName = "sqlmi-pc-db-01"
$ResourceGroupName = "rg-sqlmi-pc-db-01"

#Set restore time (specific time UTC or latest possible time UTC). Uncomment and comment out relevant lines.
#$RestorePITRtime = "2023-06-20 08:00:00" #specify time in UTC 
#$RestorePITRtime = [datetime]"$RestorePITRtime-00:00" #convert to UTC
$RestorePITRtime=Get-Date #get current time
$RestorePITRtime=$RestorePITRtime.ToUniversalTime() #convert to UTC

Set-AzContext -SubscriptionId $SubscriptionId

$Databases = Get-AzSqlInstanceDatabase  -InstanceName $InstanceName -ResourceGroupName  $ResourceGroupName 
for ($i=  0; $i -lt $Databases.length; $i++)  {  `
  $database =  $Databases.Name
  Write-Host "Target database name: " "$($database[$i])_restored"
  Write-Host 'Try to get PITR backup from UTC time:' $RestorePITRtime
  Restore-AzSqlInstanceDatabase -FromPointInTimeBackup -ResourceGroupName $ResourceGroupName  -InstanceName  $InstanceName `
  -Name $database[$i] -PointInTime $RestorePITRtime -TargetInstanceDatabaseName "$($database[$i])_restored"
  }

######## 2A Restore SINGLE database to DIFFERENT managed instance in same SUB from PITR backup to latest/specified restore time ###########################################################################
$SubscriptionId = "c0723d0a-90a1-42b0-ba86-efd217b7483e"
$srcInstanceName = "sqlmi-pc-db-02" #source
$srcResourceGroupName = "rg-sqlmi-pc-db-02" #source
$dstInstanceName = "sqlmi-pc-db-01" #destination
$dstResourceGroupName = "rg-sqlmi-pc-db-01" #destination
$Database="IF_SysMan"

#Set restore time (specific time UTC or latest possible time UTC). Uncomment and comment out relevant lines.
#$RestorePITRtime = "2023-06-20 08:00:00" #specify time in UTC 
#$RestorePITRtime = [datetime]"$RestorePITRtime-00:00" #convert to UTC
$RestorePITRtime=Get-Date #get current time
$RestorePITRtime=$RestorePITRtime.ToUniversalTime() #convert to UTC

#Before copying backup from src to dst must make sure that default TDE key from src is presented on dst SQLMI
Set-AzContext -SubscriptionId $SubscriptionId
$srcTDEkey=Get-AzSqlInstanceTransparentDataEncryptionProtector -InstanceName $srcInstanceName -ResourceGroupName $srcResourceGroupName
if ($srcTDEkey.KeyId -eq $null) {write-host 'CMK TDE key not set on source. Please set it before proceed.'} else {
    $dstTDEkey=Get-AzSqlInstanceKeyVaultKey -InstanceName $dstInstanceName -ResourceGroupName $dstResourceGroupName
    $countern = 0
    for ($i=  0; $i -lt $dstTDEkey.length; $i++)  {  `
      $keyid =  $dstTDEkey.KeyId
        if ($keyid[$i] -eq $srcTDEkey.KeyId) {
            Write-Host "TDE key found on destination SQLMI"
            } else {
            $countern++
            $array += $keyid[$i]
            }
      }
    if ($dstTDEkey.length -eq $countern) {
    Write-Host "TDE key NOT found on destination SQLMI. Will try to map key"
    Add-AzSqlInstanceKeyVaultKey -ResourceGroupName $dstResourceGroupName -InstanceName $dstInstanceName -KeyId $srcTDEkey.KeyId
    }
}

#Restore
Write-Host 'Try to get PITR backup from UTC time:' $RestorePITRtime
Write-Host 'Target database name:' $Database"_restored"
Restore-AzSqlInstanceDatabase -FromPointInTimeBackup -ResourceGroupName $srcResourceGroupName  -InstanceName  $srcInstanceName `
-Name $Database -PointInTime $RestorePITRtime -TargetInstanceDatabaseName $Database"_restored" -TargetResourceGroupName $dstResourceGroupName -TargetInstanceName $dstInstanceName

######## 2B Restore ALL databases to DIFFERENT managed instance in same SUB from PITR backup to latest/specified restore time ###########################################################################
$SubscriptionId = "c0723d0a-90a1-42b0-ba86-efd217b7483e"
$srcInstanceName = "sqlmi-pc-db-02" #source
$srcResourceGroupName = "rg-sqlmi-pc-db-02" #source
$dstInstanceName = "sqlmi-pc-db-01" #destination
$dstResourceGroupName = "rg-sqlmi-pc-db-01" #destination

#Set restore time (specific time UTC or latest possible time UTC). Uncomment and comment out relevant lines.
#$RestorePITRtime = "2023-06-20 08:00:00" #specify time in UTC 
#$RestorePITRtime = [datetime]"$RestorePITRtime-00:00" #convert to UTC
$RestorePITRtime=Get-Date #get current time
$RestorePITRtime=$RestorePITRtime.ToUniversalTime() #convert to UTC

#Before copying backup from src to dst must make sure that default TDE key from src is presented on dst SQLMI
Set-AzContext -SubscriptionId $SubscriptionId
$srcTDEkey=Get-AzSqlInstanceTransparentDataEncryptionProtector -InstanceName $srcInstanceName -ResourceGroupName $srcResourceGroupName
if ($srcTDEkey.KeyId -eq $null) {write-host 'CMK TDE key not set on source. Please set it before proceed.'} else {
    $dstTDEkey=Get-AzSqlInstanceKeyVaultKey -InstanceName $dstInstanceName -ResourceGroupName $dstResourceGroupName
    $countern = 0
    for ($i=  0; $i -lt $dstTDEkey.length; $i++)  {  `
      $keyid =  $dstTDEkey.KeyId
        if ($keyid[$i] -eq $srcTDEkey.KeyId) {
            Write-Host "TDE key found on destination SQLMI"
            } else {
            $countern++
            $array += $keyid[$i]
            }
      }
    if ($dstTDEkey.length -eq $countern) {
    Write-Host "TDE key NOT found on destination SQLMI. Will try to map key"
    Add-AzSqlInstanceKeyVaultKey -ResourceGroupName $dstResourceGroupName -InstanceName $dstInstanceName -KeyId $srcTDEkey.KeyId
    }
}

#Restore
$Databases = Get-AzSqlInstanceDatabase  -InstanceName $srcInstanceName -ResourceGroupName  $srcResourceGroupName  
for ($i=  0; $i -lt $Databases.length; $i++)  {  `
  $database =  $Databases.Name
  Write-Host "Target database name: " "$($database[$i])_restored"
  Write-Host 'Try to get PITR backup from UTC time:' $RestorePITRtime
  Restore-AzSqlInstanceDatabase -FromPointInTimeBackup -ResourceGroupName $srcResourceGroupName  -InstanceName  $srcInstanceName `
  -Name $database[$i] -PointInTime $RestorePITRtime -TargetInstanceDatabaseName "$($database[$i])_restored" -TargetResourceGroupName $dstResourceGroupName -TargetInstanceName $dstInstanceName
  }

######## 3A Restore SINGLE database to DIFFERENT managed instance in different SUB from PITR backup to latest/specified restore time ################################################
$srcSubscriptionId = "ca352517-27bb-41fc-98e0-22e58196594e" #source
$srcInstanceName = "sqlmi-pr-db-01" #source
$srcResourceGroupName = "rg-sqlmi-pr-db-01" #source
$dstSubscriptionID = "c0723d0a-90a1-42b0-ba86-efd217b7483e"
$dstInstanceName = "sqlmi-pc-db-02" #destination
$dstResourceGroupName = "rg-sqlmi-pc-db-02" #destination
$Database="dbpr1"

#Set restore time (specific time UTC or latest possible time UTC). Uncomment and comment out relevant lines.
#$RestorePITRtime = "2023-06-20 08:00:00" #specify time in UTC 
#$RestorePITRtime = [datetime]"$RestorePITRtime-00:00" #convert to UTC
$RestorePITRtime=Get-Date #get current time
$RestorePITRtime=$RestorePITRtime.ToUniversalTime() #convert to UTC

#Before copying backup from src to dst must make sure that default TDE key from src is presented on dst SQLMI
Set-AzContext -SubscriptionId $srcSubscriptionId
$srcTDEkey=Get-AzSqlInstanceTransparentDataEncryptionProtector -InstanceName $srcInstanceName -ResourceGroupName $srcResourceGroupName
$srcTDEkey.KeyId
Set-AzContext -SubscriptionId $dstSubscriptionID
$dstTDEkey=Get-AzSqlInstanceKeyVaultKey -InstanceName $dstInstanceName -ResourceGroupName $dstResourceGroupName
if ($srcTDEkey.KeyId -eq $null) {write-host 'CMK TDE key not set on source. Please set it before proceed.'} else {
    $countern = 0
    for ($i=  0; $i -lt $dstTDEkey.length; $i++)  {  `
      $keyid =  $dstTDEkey.KeyId
        if ($keyid[$i] -eq $srcTDEkey.KeyId) {
            Write-Host "TDE key found on destination SQLMI"
            } else {
            $countern++
            $array += $keyid[$i]
            }
      }
    if ($dstTDEkey.length -eq $countern) {
    Write-Host "TDE key NOT found on destination SQLMI. Will try to map key"
    Add-AzSqlInstanceKeyVaultKey -ResourceGroupName $dstResourceGroupName -InstanceName $dstInstanceName -KeyId $srcTDEkey.KeyId
    }
}

#Restore
Set-AzContext -SubscriptionId $srcSubscriptionId
$Databases = Get-AzSqlInstanceDatabase -Name $Database -InstanceName $srcInstanceName -ResourceGroupName $srcResourceGroupName
Set-AzContext -SubscriptionId $dstSubscriptionID
Write-Host 'Try to get PITR backup from UTC time:' $RestorePITRtime
Write-Host 'Target database name:' $Database"_restored"
$Databases|Restore-AzSqlInstanceDatabase -FromPointInTimeBackup -PointInTime $RestorePITRtime -TargetInstanceDatabaseName $Database"_restored" -TargetResourceGroupName $dstResourceGroupName `
-TargetInstanceName $dstInstanceName -TargetSubscriptionId $dstSubscriptionID
  
######## 3B Restore ALL databases to DIFFERENT managed instance in different SUB from PITR backup to latest/specified restore time ################################################
$srcSubscriptionId = "ca352517-27bb-41fc-98e0-22e58196594e" #source
$srcInstanceName = "sqlmi-pr-db-01" #source
$srcResourceGroupName = "rg-sqlmi-pr-db-01" #source
$dstSubscriptionID = "c0723d0a-90a1-42b0-ba86-efd217b7483e"
$dstInstanceName = "sqlmi-pc-db-02" #destination
$dstResourceGroupName = "rg-sqlmi-pc-db-02" #destination

#Set restore time (specific time UTC or latest possible time UTC). Uncomment and comment out relevant lines.
#$RestorePITRtime = "2023-06-20 08:00:00" #specify time in UTC 
#$RestorePITRtime = [datetime]"$RestorePITRtime-00:00" #convert to UTC
$RestorePITRtime=Get-Date #get current time
$RestorePITRtime=$RestorePITRtime.ToUniversalTime() #convert to UTC

#Before copying backup from src to dst must make sure that default TDE key from src is presented on dst SQLMI
Set-AzContext -SubscriptionId $srcSubscriptionId
$srcTDEkey=Get-AzSqlInstanceTransparentDataEncryptionProtector -InstanceName $srcInstanceName -ResourceGroupName $srcResourceGroupName
Set-AzContext -SubscriptionId $dstSubscriptionID
$dstTDEkey=Get-AzSqlInstanceKeyVaultKey -InstanceName $dstInstanceName -ResourceGroupName $dstResourceGroupName
if ($srcTDEkey.KeyId -eq $null) {write-host 'CMK TDE key not set on source. Please set it before proceed.'} else {
    $countern = 0
    for ($i=  0; $i -lt $dstTDEkey.length; $i++)  {  `
      $keyid =  $dstTDEkey.KeyId
        if ($keyid[$i] -eq $srcTDEkey.KeyId) {
            Write-Host "TDE key found on destination SQLMI"
            } else {
            $countern++
            $array += $keyid[$i]
            }
      }
    if ($dstTDEkey.length -eq $countern) {
    Write-Host "TDE key NOT found on destination SQLMI. Will try to map key"
    Add-AzSqlInstanceKeyVaultKey -ResourceGroupName $dstResourceGroupName -InstanceName $dstInstanceName -KeyId $srcTDEkey.KeyId
    }
}
#Restore
Set-AzContext -SubscriptionId $srcSubscriptionId
$Databases = Get-AzSqlInstanceDatabase  -InstanceName $srcInstanceName -ResourceGroupName  $srcResourceGroupName 
Set-AzContext -SubscriptionId $dstSubscriptionID 
for ($i=  0; $i -lt $Databases.length; $i++)  {  `
  $database =  $Databases.Name
  Write-Host "Target database name: " "$($database[$i])_restored"
  Write-Host 'Try to get PITR backup from UTC time:' $RestorePITRtime
  $database[$i]| Restore-AzSqlInstanceDatabase -FromPointInTimeBackup -SubscriptionId $srcSubscriptionId -ResourceGroupName $srcResourceGroupName  -InstanceName  $srcInstanceName `
  -Name $database[$i] -PointInTime $RestorePITRtime -TargetInstanceDatabaseName "$($database[$i])_restored" -TargetResourceGroupName $dstResourceGroupName -TargetInstanceName $dstInstanceName -TargetSubscriptionId $dstSubscriptionID
  }


 
######## 4 Restore ALL databases to DIFFERENT managed instance in same SUB but DIFFERENT region from GEO backup to defined* time ################################################
$srcSubscriptionId = "ca352517-27bb-41fc-98e0-22e58196594e" #source
$srcInstanceName = "sqlmi-pr-db-01" #source
$srcResourceGroupName = "rg-sqlmi-pr-db-01" #source
$dstSubscriptionID = "c0723d0a-90a1-42b0-ba86-efd217b7483e"
$dstInstanceName = "sqlmi-pc-db-02" #destination
$dstResourceGroupName = "rg-sqlmi-pc-db-02" #destination

#Before copying backup from src to dst must make sure that default TDE key from src is presented on dst SQLMI
Set-AzContext -SubscriptionId $srcSubscriptionId
$srcTDEkey=Get-AzSqlInstanceTransparentDataEncryptionProtector -InstanceName $srcInstanceName -ResourceGroupName $srcResourceGroupName
Set-AzContext -SubscriptionId $dstSubscriptionID
$dstTDEkey=Get-AzSqlInstanceKeyVaultKey -InstanceName $dstInstanceName -ResourceGroupName $dstResourceGroupName
if ($srcTDEkey.KeyId -eq $null) {write-host 'CMK TDE key not set on source. Please set it before proceed.'} else {
    $countern = 0
    for ($i=  0; $i -lt $dstTDEkey.length; $i++)  {  `
      $keyid =  $dstTDEkey.KeyId
        if ($keyid[$i] -eq $srcTDEkey.KeyId) {
            Write-Host "TDE key found on destination SQLMI"
            } else {
            $countern++
            $array += $keyid[$i]
            }
      }
    if ($dstTDEkey.length -eq $countern) {
    Write-Host "TDE key NOT found on destination SQLMI. Will try to map key"
    Add-AzSqlInstanceKeyVaultKey -ResourceGroupName $dstResourceGroupName -InstanceName $dstInstanceName -KeyId $srcTDEkey.KeyId
    }
}

#Restore
$Databases = Get-AzSqlInstanceDatabase  -InstanceName $srcInstanceName -ResourceGroupName  $srcResourceGroupName  
for ($i=  0; $i -lt $Databases.length; $i++)  {  `
  $database =  $Databases.Name
  $GeoBackup = Get-AzSqlInstanceDatabaseGeoBackup -ResourceGroupName $srcResourceGroupName -InstanceName $srcInstanceName -Name $database[$i]
  $geotime = $GeoBackup.LastAvailableBackupDate
  Write-Host 'Try to get latest GEO backup from UTC time:' $geotime
  Write-Host "Target database name: " "$($database[$i])_restored"
  $GeoBackup | Restore-AzSqlInstanceDatabase -FromGeoBackup -TargetInstanceDatabaseName "$($database[$i])_restored" -TargetInstanceName $dstInstanceName -TargetResourceGroupName $dstResourceGroupName
  }

######## 5A Restore SINGLE database to SAME manage instance in same SUB from LTR to latest/chosen from list restore time ###############################################
$SubscriptionId = "c0723d0a-90a1-42b0-ba86-efd217b7483e"
$InstanceName = "sqlmi-pc-db-02"
$ResourceGroupName = "rg-sqlmi-pc-db-02" 
$Location="WestEurope"
$Database="IF_SysMan"

#Restore
Set-AzContext -SubscriptionId $SubscriptionId

$Databases = Get-AzSqlInstanceDatabaseLongTermRetentionBackup -InstanceName $InstanceName -ResourceGroupName $ResourceGroupName -Location $Location -DatabaseState "Live" -OnlyLatestPerDatabase |Where-Object {$_.DatabaseName -eq $Database}
Write-Host 'Try to get latest LTR backup from UTC time:' $Databases.BackupTime
Write-Host 'Target database name:' $Database"_restored"
$Databases |Where-Object {$_.DatabaseName -eq $Database}|Restore-AzSqlInstanceDatabase -FromLongTermRetentionBackup -TargetInstanceDatabaseName $Database"_restored" -TargetInstanceName $InstanceName -TargetResourceGroupName $ResourceGroupName


######## 5B Restore ALL databases to SAME manage instance in same SUB from LTR to latest/chosen from list restore timee ################################################
$SubscriptionId = "c0723d0a-90a1-42b0-ba86-efd217b7483e"
$InstanceName = "sqlmi-pc-db-01"
$ResourceGroupName = "rg-sqlmi-pc-db-01" 
$Location="WestEurope"

#Set restore time (specific time UTC or latest possible time UTC). Uncomment and comment out relevant lines.
#$RestorePITRtime = "2023-06-20 08:00:00" #specify time in UTC 
#$RestorePITRtime = [datetime]"$RestorePITRtime-00:00" #convert to UTC
$RestorePITRtime=Get-Date #get current time
$RestorePITRtime=$RestorePITRtime.ToUniversalTime() #convert to UTC


#Restore
Set-AzContext -SubscriptionId $SubscriptionId
$Databases = Get-AzSqlInstanceDatabaseLongTermRetentionBackup -InstanceName $InstanceName -ResourceGroupName $ResourceGroupName -Location $Location -DatabaseState "Live" -OnlyLatestPerDatabase 
for ($i=  0; $i -lt $Databases.length; $i++)  {  `
  $database =  $Databases.DatabaseName
  $ltrrime = $Databases.BackupTime 
  Write-Host "Target database name:" $($database[$i])_restored 
  Write-Host "Using LTR backup from UTC time:" $ltrrime[$i]
  Restore-AzSqlInstanceDatabase -FromLongTermRetentionBackup -ResourceId $resourceid[$i] -TargetInstanceDatabaseName "$($database[$i])_restored" -TargetInstanceName $InstanceName -TargetResourceGroupName $ResourceGroupName
  }



######## 6 Restore SINGLE database to SAME managed instance in same sub if it was deleted from latest deletion point ################################################################################
$SubscriptionId = "c0723d0a-90a1-42b0-ba86-efd217b7483e"
$InstanceName = "sqlmi-pc-db-01"
$ResourceGroupName = "rg-sqlmi-pc-db-01" 
$Database="IF_SysMan"

#Restore
Set-AzContext -SubscriptionId $SubscriptionId
$deletedDatabase = Get-AzSqlDeletedInstanceDatabaseBackup -ResourceGroupName $ResourceGroupName -InstanceName $InstanceName -DatabaseName $Database
Write-Host 'Try to get latest LTR backup from UTC time:' $deletedDatabase[0].DeletionDate
Write-Host 'Target database name:' $Database"_restored"
Restore-AzSqlInstanceDatabase -FromPointInTimeBackup -InputObject $deletedDatabase[0] -PointInTime $deletedDatabase[0].DeletionDate -TargetInstanceDatabaseName $Database"_restored"
