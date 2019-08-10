New-Alias -Name 'genrsa' -Value 'New-RSAKeyPair'
New-Alias -Name 'genssh' -Value 'New-RSAKeyPair'
New-Alias -Name 'genkey' -Value 'New-RSAKeyPair'
Export-ModuleMember -Alias @('genrsa','genssh','genkey')
