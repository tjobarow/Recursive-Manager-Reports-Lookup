function MapUserLaptop {
    param (
        $userLaptopHT
    )

    Write-Host "In the user mapping function..."

    $reportMachineList=@()

    foreach ($laptop in $userLaptopHT.GetEnumerator()) {
        #Write-Output $laptop.values
        
        
        $upn=$laptop.Value.UserName -split "\\"
        $nuid=$upn[1]
        if ($nuid -like "$*") {
            $duid=$nuid
            $nuid=$nuid.Trim("$")
        } else {
            $duid="$"+$nuid
        }
        #Write-Output $uid

        if ($listOfReports[$nuid] -ne $null) {
            Write-Output "Match found: $($listOfReports[$nuid].Name) (UID of $($nuid)) has laptop $($laptop.Value.ComputerName)"
            $reportMachineHT=@{"Name"=$listOfReports[$nuid].Name;"ID"=$nuid;"Email"=$listOfReports[$nuid].EmailAddress;"Hostname"=$laptop.Value.ComputerName}
            $reportMachinePSObj=[PSCustomObject]$reportMachineHT
            $reportMachineList+=,$reportMachinePSObj
            #Write-Output $reportMachineHT
        } elseif($listOfReports[$duid] -ne $null) {
            Write-Output "Match found: $($listOfReports[$duid].Name) (UID of $($duid)) has laptop $($laptop.Value.ComputerName)"
            $reportMachineHT=@{"Name"=$listOfReports[$nuid].Name;"ID"=$nuid;"Email"=$listOfReports[$nuid].EmailAddress;"Hostname"=$laptop.Value.ComputerName}
            $reportMachinePSObj=[PSCustomObject]$reportMachineHT
            $reportMachineList+=,$reportMachinePSObj
            #Write-Output $reportMachineHT
        }
        
    }

    $reportMachineList | Select Name,ID,Email,Hostname | Export-Csv -Path "./manager_reports_laptops.csv" -NoTypeInformation

    <#
    foreach ($report in $listOfReports) {
        $splitUPN = $report."UserPrincipalName" -split "@"
        $dSignAccount="JDL\$"+$splitUPN[0]
        $normAccount="JDL\"+$splitUPN[0]
        
        


        #Write-Host $dSignAccount
        #Write-Host $normAccount
        
        if ($userLaptopHT[$dSignAccount] -ne $null) {
            Write-Output $userLaptopHT[$dSignAccount]

            $MappingObject | Add-Member -MemberType NoteProperty -Name "Computer Name" -Value $userLaptopHT[$normAccount]["Computer Name"]
            $MappingObject | Add-Member -MemberType NoteProperty -Name "User Name" -Value $normAccount
            $MappingObject | Add-Member -MemberType NoteProperty -Name Name -Value $report."Name"

            $userMappingList+=$MappingObject
        }
        if ($userLaptopHT[$normAccount] -ne $null) {
            $MappingObject | Add-Member -MemberType NoteProperty -Name "Computer Name" -Value $userLaptopHT[$normAccount]["Computer Name"]
            $MappingObject | Add-Member -MemberType NoteProperty -Name "User Name" -Value $normAccount
            $MappingObject | Add-Member -MemberType NoteProperty -Name Name -Value $report."Name"

            $userMappingList+=$MappingObject
        }
        
    }#>

    Write-Output $userMappingList
}

function TaniumInventoryMapping {

    $taniumAssets = Import-Csv -Path ".\All_Assets_Tanium.csv"

    $userLaptopHT = @{}

    foreach ($asset in $taniumAssets) {
        if (($asset."Computer Name" -match "LP-S") -And ($asset."User Name" -ne "") ) {
            Write-Host $asset."User Name"
            try {
                $userLaptopHT.Add($asset."Computer Name",@{"UserName"=$asset."User Name";"ComputerName"=$asset."Computer Name"})
            }
            catch {
                continue
            }
            Write-Host "Getting Tanium Asset information: "+$asset.'Computer Name'
            Write-Host "Getting Tanium Asset information: "+$asset.'User Name'
        }
    }

    return $userLaptopHT


}


function RecurseDirectReports {
    param ($ADUser)
    $CN=$ADUser."DistinguishedName"
    $upn=$ADUser."UserPrincipalName" -split "@"
    $uid=$upn[0]
    $global:listOfReports.Add($uid,$ADUser)
    Write-Host "GETTING USER INFORMATION:"+$ADUser.Name
    $direct_reports=get-aduser -filter {Manager -eq $CN} -properties UserPrincipalName,Manager,Name,DistinguishedName,Description,EmailAddress
    if ($direct_reports -eq $null) {
        #Write-Host "$($ADUser."DistinguishedName") is not a manager"
        return $ADUser
    }
    else {
        #Write-Host "$($ADUser."DistinguishedName") has direct reports"
        foreach ($dr in $direct_reports) {
            #Write-Host "***********************************"
            #Write-Host $dr."DistinguishedName"
            <#if ($dr.Description -like "Service*Desk*Technician"){
                continue
            }#>
            RecurseDirectReports -ADUser $dr

        }
        return $ADUser
    }
    #return $listOfReports
}


$global:listOfReports = @{}

$manager="Lonnie Farmer"
$ADUser=Get-ADUser -filter {Name -eq $manager} -properties UserPrincipalName,Manager,Name,DistinguishedName,Description,EmailAddress

RecurseDirectReports -ADUser $ADUser
$global:listOfReports | Select Name,DistinguishedName,Manager,UserPrincipalName | Export-Csv -Path "./$($manager)_direct_reports.csv" -NoTypeInformation

$userLaptopHT=TaniumInventoryMapping

MapUserLaptop -userLaptopHT $userLaptopHT
