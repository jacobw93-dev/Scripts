# Your AES key (must be 16/24/32 chars = 128/192/256 bits)
$aesKey = "..."   # 16 chars -> 128-bit key
$plainSecret = "..."

function Store-EncryptedSecretToCredentialManager {
    param(
        [string]$PlainSecret,
        [string]$AESKey,
        [string]$AESKeyTarget = "PBIAppAESKey",
        [string]$EncryptedSecretTarget = "PBIAppEncryptedSecret",
        [switch]$Overwrite
    )

    Import-Module CredentialManager -ErrorAction Stop

    # Convert key string to bytes (UTF8)
    $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($AESKey)

    if ($keyBytes.Length -notin 16,24,32) {
        throw "AES key must be 16, 24, or 32 characters long. Yours is $($keyBytes.Length)."
    }

    $aesProv = [System.Security.Cryptography.AesCryptoServiceProvider]::new()
    $aesProv.Mode    = [System.Security.Cryptography.CipherMode]::CBC
    $aesProv.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aesProv.Key     = $keyBytes
    $aesProv.IV      = [byte[]]::new(16)   # fixed zero IV, matches decryption

    $encryptor = $aesProv.CreateEncryptor()
    $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainSecret)
    $encryptedBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
    $encryptedBase64 = [Convert]::ToBase64String($encryptedBytes)

    # Remove old credentials if overwrite requested
    if ($Overwrite) {
        Remove-StoredCredential -Target $AESKeyTarget -ErrorAction SilentlyContinue
        Remove-StoredCredential -Target $EncryptedSecretTarget -ErrorAction SilentlyContinue
    }

    # Store AES key as plain string
    New-StoredCredential -Target $AESKeyTarget -UserName "AESKey" -Password $AESKey -Persist LocalMachine | Out-Null
    # Store encrypted secret as base64
    New-StoredCredential -Target $EncryptedSecretTarget -UserName "ServicePrincipal" -Password $encryptedBase64 -Persist LocalMachine | Out-Null

    Write-Host "Stored AES key ('$AESKeyTarget') and encrypted secret ('$EncryptedSecretTarget') in Credential Manager."
}

Store-EncryptedSecretToCredentialManager -PlainSecret $plainSecret -AESKey $aesKey -Overwrite