﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\CPU-Rplant\cpuminer-$($f = $Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'ryzen'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.aes){'aes'}elseif($f.sse42){'sse42'}else{'sse2'}))"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v4.0.12-rplant/cpuminer-rplant-4.0.12-linux.tar.gz"
} else {
    $Path = ".\Bin\CPU-Rplant\cpuminer-$($f = $Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'ryzen'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.aes){'aes'}elseif($f.sse42){'sse42'}elseif([Environment]::Is64BitOperatingSystem){'sse2'}else{'sse2-w32'})).exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v4.0.12-rplant/cpuminer-rplant-4.0.12-win.zip"
}
$ManualUri = "https://pool.rplant.xyz/miners"
$Port = "532{0:d2}"
$DevFee = 0.0

if (-not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "argon2ad"; Params = ""; ExtendInterval = 2} #Argon2ad
    [PSCustomObject]@{MainAlgorithm = "argon2d500"; Params = ""; ExtendInterval = 2} #Argon2d500
    [PSCustomObject]@{MainAlgorithm = "argon2d4096"; Params = ""; ExtendInterval = 2} #Argon2d4096
    [PSCustomObject]@{MainAlgorithm = "argon2m"; Params = ""; ExtendInterval = 2} #Argon2m
    [PSCustomObject]@{MainAlgorithm = "honeycomb"; Params = ""; ExtendInterval = 2} #Honeycomb
    [PSCustomObject]@{MainAlgorithm = "lyra2cz"; Params = ""; ExtendInterval = 2} #Lyra2cz
    [PSCustomObject]@{MainAlgorithm = "lyra2z330"; Params = ""; ExtendInterval = 2} #Lyra2z330
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = ""; ExtendInterval = 2} #YescryptR16
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = ""; ExtendInterval = 2} #YescryptR32
    [PSCustomObject]@{MainAlgorithm = "yescryptr8g"; Params = ""; ExtendInterval = 2} #YescryptR8g (KOTO)
    [PSCustomObject]@{MainAlgorithm = "yespowerr16"; Params = ""; ExtendInterval = 2} #YespowerR16
    [PSCustomObject]@{MainAlgorithm = "yespowerLTNCG"; Params = ""; ExtendInterval = 2} #Yespower LighningCash-Gold v3
    [PSCustomObject]@{MainAlgorithm = "yespowerSUGAR"; Params = ""; ExtendInterval = 2} #Yespower SugarChain
    [PSCustomObject]@{MainAlgorithm = "yespowerURX"; Params = ""; ExtendInterval = 2} #Yespower Uranium-X
    [PSCustomObject]@{MainAlgorithm = "Binarium_hash_v1"; Params = ""; ExtendInterval = 2} #Binarium
)

if ($IsLinux) {
    $Commands += [PSCustomObject[]]@(
        [PSCustomObject]@{MainAlgorithm = "argon2d250"; Params = ""; ExtendInterval = 2} #Argon2d250
        [PSCustomObject]@{MainAlgorithm = "cpupower"; Params = ""; ExtendInterval = 2} #CpuPower
        [PSCustomObject]@{MainAlgorithm = "lyra2h"; Params = ""; ExtendInterval = 2} #Lyra2h
        [PSCustomObject]@{MainAlgorithm = "scryptjane:16"; Params = ""; ExtendInterval = 2} #ScryptJane16
        [PSCustomObject]@{MainAlgorithm = "scrypt:1048576"; Params = ""; ExtendInterval = 2} #Verium
        [PSCustomObject]@{MainAlgorithm = "yescryptr8"; Params = ""; ExtendInterval = 2} #YescryptR8
        [PSCustomObject]@{MainAlgorithm = "yespower"; Params = ""; ExtendInterval = 2} #Yespower
    )
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("CPU")
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

$Session.DevicesByTypes.CPU | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.DevicesByTypes.CPU | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $DeviceParams = "$(if ($Session.Config.CPUMiningThreads){"-t $($Session.Config.CPUMiningThreads)"}) $(if ($Session.Config.CPUMiningAffinity -ne ''){"--cpu-affinity $($Session.Config.CPUMiningAffinity)"})"

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and ($Algorithm_Norm -ne "Lyra2z330" -or $Pools.$Algorithm_Norm.Name -ne "Zpool")) {
				[PSCustomObject]@{
					Name = $Miner_Name
					DeviceName = $Miner_Device.Name
					DeviceModel = $Miner_Model
					Path = $Path
					Arguments = "-b $($Miner_Port) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($DeviceParams) $($_.Params)"
					HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					API = "Ccminer"
					Port = $Miner_Port
					Uri = $Uri
					FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
					DevFee = $DevFee
					ManualUri = $ManualUri
				}
			}
		}
    }
}