Clean Temporary Files
Deletes files from Windows Prefetch, User Temp and Windows Temp folders.

Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force
Remove-Item -Path "C:\Windows\Prefetch\*" -Recurse -Force

Run Disk Cleanup
Runs cleanmgr.exe.

cleanmgr /verylowdisk /sagerun:5

Empty Recycle Bin
Uses PowerShell to empty the Recycle Bin by iterating through its items and removing them forcefully. It also prints a message indicating which item is being deleted.

$bin = (New-Object -ComObject Shell.Application).NameSpace(10); $bin.items() | ForEach { Write-Host "Deleting $($_.Name) from Recycle Bin"; Remove-Item $_.Path -Recurse -Force }

SFC Check
Checks if the system integrity is correct, and if not, fixes the corrupted files.

sfc /scannow