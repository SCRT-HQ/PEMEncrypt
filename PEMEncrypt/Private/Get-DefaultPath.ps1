function Get-DefaultPath {
    [CmdletBinding()]
    Param()
    Process {
        $homePath = if ($HOME) {
            $HOME
        }
        elseif (Test-Path "~") {
            (Resolve-Path "~").Path
        }
        [System.IO.Path]::Combine($homePath,".ssh","id_rsa")
    }
}
