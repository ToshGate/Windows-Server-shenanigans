# Must be run with administrative privileges

# Output path
$csvPath = "C:\Cluster_VM_Usage_Report.csv"

# Initialize data
$vmInfoList = @()

# Get cluster name and nodes
$clusterName = (Get-Cluster).Name
$nodes = Get-ClusterNode

Write-Host "🧠 Collecting VM data from cluster: $clusterName..." -ForegroundColor Cyan

foreach ($node in $nodes) {
    $nodeName = $node.Name
    Write-Host "`n🔍 Scanning node: $nodeName" -ForegroundColor Yellow

    try {
        # Run all VM and VHD queries remotely on the node
        $vmInfoOnNode = Invoke-Command -ComputerName $nodeName -ScriptBlock {
            param($nodeNameParam)

            $vmInfoListNode = @()

            # Get VMs on this node
            $vms = Get-VM

            foreach ($vm in $vms) {
                $vmName = $vm.Name
                $vmState = $vm.State
                $status = if ($vmState -ne 'Running') { "VM off" } else { "Running" }

                $cpuCount = ($vm | Get-VMProcessor).Count
                $ramAllocated = [math]::Round($vm.MemoryAssigned / 1GB, 2)
                $ramUsed = [math]::Round($vm.MemoryDemand / 1GB, 2)

                $diskAllocated = 0
                $diskUsed = 0

                $vmHardDrives = Get-VMHardDiskDrive -VMName $vmName
                foreach ($drive in $vmHardDrives) {
                    $vhdPath = $drive.Path
                    if (Test-Path $vhdPath) {
                        try {
                            $vhdInfo = Get-VHD -Path $vhdPath -ErrorAction Stop
                            $diskAllocated += [math]::Round($vhdInfo.Size / 1GB, 2)
                            $diskUsed += [math]::Round($vhdInfo.FileSize / 1GB, 2)
                        } catch {
                            Write-Warning "⚠️ Unable to get VHD info for $vhdPath. It might be in use or locked."
                        }
                    }
                }

                $vmInfo = [PSCustomObject]@{
                    Cluster_Node   = $nodeNameParam
                    VM_Name        = $vmName
                    Status         = $status
                    CPU_Count      = $cpuCount
                    RAM_Allocated  = "$ramAllocated GB"
                    RAM_Used       = "$ramUsed GB"
                    Disk_Allocated = "$diskAllocated GB"
                    Disk_Used      = "$diskUsed GB"
                }

                $vmInfoListNode += $vmInfo
            }

            return $vmInfoListNode
        } -ArgumentList $nodeName -ErrorAction Stop

        $vmInfoList += $vmInfoOnNode

    } catch {
        Write-Warning "⚠️ Could not collect VM data from $nodeName : $_"
        continue
    }
}

# Totals row
$totalRow = [PSCustomObject]@{
    Cluster_Node   = $clusterName
    VM_Name        = "TOTAL"
    Status         = ""
    CPU_Count      = ($vmInfoList | Measure-Object -Property CPU_Count -Sum).Sum
    RAM_Allocated  = "$(($vmInfoList | ForEach-Object { ($_.'RAM_Allocated' -replace ' GB','') -as [double] } | Measure-Object -Sum).Sum) GB"
    RAM_Used       = "$(($vmInfoList | ForEach-Object { ($_.'RAM_Used' -replace ' GB','') -as [double] } | Measure-Object -Sum).Sum) GB"
    Disk_Allocated = "$(($vmInfoList | ForEach-Object { ($_.'Disk_Allocated' -replace ' GB','') -as [double] } | Measure-Object -Sum).Sum) GB"
    Disk_Used      = "$(($vmInfoList | ForEach-Object { ($_.'Disk_Used' -replace ' GB','') -as [double] } | Measure-Object -Sum).Sum) GB"
}
$vmInfoList += $totalRow

# Output to console
#$vmInfoList | Format-Table -AutoSize

# Export to CSV
#$vmInfoList | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

#Write-Host "`n✅ CSV report saved to: $csvPath" -ForegroundColor Green




# Select only needed columns
$cleanVmInfoList = $vmInfoList | Select-Object Cluster_Node, VM_Name, Status, CPU_Count, RAM_Allocated, RAM_Used, Disk_Allocated, Disk_Used

# Output to console
$cleanVmInfoList | Format-Table -AutoSize

# Export to CSV
$cleanVmInfoList | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Host "`n✅ CSV report saved to: $csvPath" -ForegroundColor Green

start c:\