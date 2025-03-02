# Definir el rango de tiempo (últimos 30 días)
$StartDate = (Get-Date).AddDays(-30)
$LogName = "Security"

# Obtener el nombre del equipo y la fecha actual
$HostName = $env:COMPUTERNAME
$Date = Get-Date -Format "yyyyMMdd_HHmmss"
$FilePath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\${HostName}_${Date}.txt"

# Obtener eventos de encendido (ID 6005 en el log de Sistema)
$BootEvents = Get-WinEvent -LogName "System" -FilterXPath "*[System[(EventID=6005) and TimeCreated >= '$StartDate']]" `
    | Select-Object TimeCreated, @{Name="Event"; Expression={"Startup"}}

# Obtener eventos de inicio de sesión interactivo (ID 4624 en el log de Seguridad)
$LoginEvents = Get-WinEvent -LogName $LogName -FilterXPath "*[System[(EventID=4624) and TimeCreated >= '$StartDate']]" `
    | ForEach-Object {
        $Xml = [xml]$_.ToXml()
        $LogonType = $Xml.Event.EventData.Data | Where-Object { $_.Name -eq "LogonType" } | Select-Object -ExpandProperty '#text'
        $UserName = $Xml.Event.EventData.Data | Where-Object { $_.Name -eq "TargetUserName" } | Select-Object -ExpandProperty '#text'

        # Filtrar solo inicios de sesión interactivos (2 = Local, 10 = Remoto) y excluir cuentas del sistema
        if (($LogonType -eq "2" -or $LogonType -eq "10") -and
            ($UserName -ne "SYSTEM") -and
            ($UserName -ne "LOCAL SERVICE") -and
            ($UserName -ne "NETWORK SERVICE") -and
            ($UserName -notmatch "\$$")) {

            [PSCustomObject]@{
                TimeCreated = $_.TimeCreated
                UserName = $UserName
                Event = "Logon"
            }
        }
    }

# Combinar eventos y ordenar por fecha
$AllEvents = $BootEvents + $LoginEvents | Sort-Object TimeCreated

# Convertir los eventos en texto y guardarlos en el archivo
$AllEvents | Format-Table TimeCreated, Event, UserName -AutoSize | Out-File -Encoding UTF8 $FilePath

# Confirmación
Write-Output "Archivo guardado en: $FilePath"
