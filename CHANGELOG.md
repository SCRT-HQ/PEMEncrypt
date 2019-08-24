* [PEMEncrypt - ChangeLog](#pemencrypt---changelog)
  * [0.2.1 - 2019-08-24](#021---2019-08-24)
  * [0.2.0 - 2019-08-10](#020---2019-08-10)
  * [0.1.1 - 2019-07-07](#011---2019-07-07)
  * [0.1.0 - 2019-07-07](#010---2019-07-07)

***

# PEMEncrypt - ChangeLog

## 0.2.1 - 2019-08-24

* [Issue #5](https://github.com/scrthq/PEMEncrypt/issues/5)
  * Added: Missing path creation to `New-RSAKeyPair` if the parent folder does not yet exist.
* Miscellaneous
  * Fixed: Error handling while using `New-RSAKeyPair -Interactive` if the specified Path already exists and `-Force` was not specified.
  * Added: Additional status updates within `New-RSAKeyPair` for a better understanding of what step the key generation is at.

## 0.2.0 - 2019-08-10

* Added `New-RSAKeyPair` to enable generation of RSA PEM and SSH keys directly from PowerShell
  * Supports password protection keys
  * Defaults to 4096 key length
  * Offers an Interactive mode using the `-Interactive` or `-i` switch to simulate `ssh-keygen` experience
* Updated README with command comparisons between `openssl`, `ssh-keygen` and `New-RSAKeyPair`

## 0.1.1 - 2019-07-07

* Added CHANGELOG, CODE_OF_CONDUCT, CONTRIBUTING docs
* Updated README with relevant badges and overall info on installing/upgrading/using the module
* Added comment-based help on the included functions
* Removed KeyLength parameter from `Protect-PEMString` (now calculating from the Modulus BitLength, so it's not necessary to specify)
* Updated `*Key` parameters on both functions to allow passing the string formatted Key directly instead of the path to it.

## 0.1.0 - 2019-07-07

* Initial release to the PowerShell Gallery
* Included functions are `Protect-PEMString` and `Unprotect-PEMString`
* Fixed deployment issue
