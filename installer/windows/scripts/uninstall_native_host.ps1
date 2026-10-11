# CreatorForge — Native Messaging Host removal (called by Inno Setup uninstaller)
$HostName = "com.creatorforge.native_host"

foreach ($browser in @("Google\Chrome", "Microsoft\Edge")) {
    $key = "HKCU:\Software\$browser\NativeMessagingHosts\$HostName"
    if (Test-Path $key) {
        Remove-Item -Path $key -Force -ErrorAction SilentlyContinue
    }
}
