﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$Path = ".\Bin\SWAP-Reference\SwapReferenceMinerCLI.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.0-swap/SwapMiner-v1.2.0-rbm.7z"
$ManualURI = "https://github.com/swap-dev/SwapReferenceMiner/releases"
$Port = "337{0:d2}"
$DevFee = 0.0
$Cuda = "9.2"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cuckaroo29s"; MinMemGb = 8; Params = ""; DevFee = 0.0; ExtendInterval = 4; FaultTolerance = 0.3; Penalty = 0; Vendor = @("AMD","NVIDIA"); NoCPUMining = $true} #SWAP/Cuckaroo29s
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

if ($Session.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Session.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
            $MinMemGb = $_.MinMemGb
            $Algorithm = $_.MainAlgorithm
            $Algorithm_Norm = Get-Algorithm $Algorithm

            $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

			foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
				if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
					$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
					$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
					$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
                
					$Arguments = [PSCustomObject]@{
						Params = "$($_.Params)".Trim()
						Config = [PSCustomObject]@{
							Host = $Pools.$Algorithm_Norm.Host
							Port = $Pool_Port
							SSL  = $Pools.$Algorithm_Norm.SSL
							User = $Pools.$Algorithm_Norm.User
							Pass = $Pools.$Algorithm_Norm.Pass
						}
						Device = @($Miner_Device | Foreach-Object {[PSCustomObject]@{Name=$_.Model_Name;Vendor=$_.Vendor;Index=$_.Type_Vendor_Index;PlatformId=$_.PlatformId}})
					}

					$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
					[PSCustomObject]@{
						Name = $Miner_Name
						DeviceName = $Miner_Device.Name
						DeviceModel = $Miner_Model
						Path = $Path                    
						Arguments = $Arguments
						HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1})}
						API = "SwapMiner"
						Port = $Miner_Port
						Uri = $Uri
						DevFee = $_.DevFee
						FaultTolerance = $_.FaultTolerance
						ExtendInterval = $_.ExtendInterval
						ManualUri = $ManualUri
						StopCommand = "Sleep 15; Get-CIMInstance CIM_Process | Where-Object ExecutablePath | Where-Object {`$_.ExecutablePath -like `"$([IO.Path]::GetFullPath($Path) | Split-Path)\*`"} | Select-Object ProcessId,ProcessName | Foreach-Object {Stop-Process -Id `$_.ProcessId -Force -ErrorAction Ignore}"
						NoCPUMining = $_.NoCPUMining
						DotNetRuntime = "2.0"
					}
				}
			}
        }
    }
}