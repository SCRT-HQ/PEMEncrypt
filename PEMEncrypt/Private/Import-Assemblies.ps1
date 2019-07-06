function Import-Assemblies {
    Param()
    Process {
        try {
            $bouncyCastleDll = [System.IO.Path]::Combine($PSScriptRoot,'bin','BouncyCastle.Crypto.dll')
            Add-Type -Path $bouncyCastleDll -ErrorAction SilentlyContinue | Out-Null
        }
        catch {
            $Global:Error.Remove($Global:Error[0])
        }
        try {
            $PEMEncrypt = [System.IO.Path]::Combine($PSScriptRoot,'bin','SCRTHQ.PEMEncrypt.dll')
            Add-Type -Path $PEMEncrypt -ReferencedAssemblies $bouncyCastleDll -ErrorAction SilentlyContinue | Out-Null
        }
        catch {
            $Global:Error.Remove($Global:Error[0])
        }
    }
}
