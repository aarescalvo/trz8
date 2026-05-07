<#
.SYNOPSIS
    Helper para enviar datos RAW a impresora Windows.
    Usado por Printer Bridge (index.js).

    Estrategia en 4 pasos:
    1) StartDocPrinter con datatype "RAW" - Zebra y compatibles
    2) StartDocPrinter con datatype null (dejar que Windows elija) - Datamax/Win10
    3) OpenPrinter con PRINTER_DEFAULTS + datatype RAW + WritePrinter
    4) Comando `print` de Windows como ultimo recurso

.PARAMETER PrinterName
    Nombre exacto de la impresora en Windows.
.PARAMETER FilePath
    Path al archivo temporal con los datos a imprimir.
.OUTPUTS
    OK:1234        (exitos, 1234 bytes escritos)
    ERROR:mensaje  (error con descripcion)
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$PrinterName,
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

# Verificar archivo existe
if (-not (Test-Path $FilePath)) {
    Write-Output "ERROR:Archivo no encontrado: $FilePath"
    exit 1
}

$fileSize = (Get-Item $FilePath).Length
if ($fileSize -eq 0) {
    Write-Output "ERROR:Archivo vacio: $FilePath"
    exit 1
}

$data = [System.IO.File]::ReadAllBytes($FilePath)

# ============================================================
# Cargar Win32 API
# ============================================================
try {
    $code = @'
using System;
using System.Runtime.InteropServices;

public class SpoolerRaw
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DOC_INFO_1
    {
        public string pDocName;
        public string pOutputFile;
        public string pDatatype;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct PRINTER_DEFAULTS
    {
        public int pDatatype;
        public int pDevMode;
        public int DesiredAccess;
    }

    [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool OpenPrinter(string pPrinterName, out IntPtr phPrinter, IntPtr pDefault);

    [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool OpenPrinter(string pPrinterName, out IntPtr phPrinter, ref PRINTER_DEFAULTS pDefault);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool StartDocPrinter(IntPtr hPrinter, int Level, ref DOC_INFO_1 pDocInfo);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool StartPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool WritePrinter(IntPtr hPrinter, byte[] pBytes, int dwCount, out int dwWritten);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool EndPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool ClosePrinter(IntPtr hPrinter);

    [DllImport("kernel32.dll")]
    public static extern uint GetLastError();
}
'@
    if (-not ([System.Management.Automation.PSTypeName]'SpoolerRaw').Type) {
        Add-Type -TypeDefinition $code -Language CSharp | Out-Null
    }
} catch {
    Write-Output "ERROR:Cargando Win32 API: $($_.Exception.Message)"
    exit 1
}

# ============================================================
# Metodo 1: Spooler con datatype "RAW"
# ============================================================
function Print-TryRaw {
    param([string]$Printer, [byte[]]$Bytes, [string]$Datatype)

    $docInfo = New-Object SpoolerRaw+DOC_INFO_1
    $docInfo.pDocName = "PrinterBridge"
    $docInfo.pOutputFile = $null
    $docInfo.pDatatype = $Datatype

    $hPrinter = [IntPtr]::Zero

    $result = [SpoolerRaw]::OpenPrinter($Printer, [ref]$hPrinter, [IntPtr]::Zero)
    if (-not $result) {
        $errCode = [SpoolerRaw]::GetLastError()
        throw "OpenPrinter codigo:$errCode"
    }

    try {
        $written = 0

        $result = [SpoolerRaw]::StartDocPrinter($hPrinter, 1, [ref]$docInfo)
        if (-not $result) {
            $errCode = [SpoolerRaw]::GetLastError()
            throw "StartDocPrinter codigo:$errCode"
        }

        $result = [SpoolerRaw]::StartPagePrinter($hPrinter)
        if (-not $result) {
            $errCode = [SpoolerRaw]::GetLastError()
            [SpoolerRaw]::EndDocPrinter($hPrinter) | Out-Null
            throw "StartPagePrinter codigo:$errCode"
        }

        $result = [SpoolerRaw]::WritePrinter($hPrinter, $Bytes, $Bytes.Length, [ref]$written)
        if (-not $result) {
            $errCode = [SpoolerRaw]::GetLastError()
            [SpoolerRaw]::EndPagePrinter($hPrinter) | Out-Null
            [SpoolerRaw]::EndDocPrinter($hPrinter) | Out-Null
            throw "WritePrinter codigo:$errCode"
        }

        [SpoolerRaw]::EndPagePrinter($hPrinter) | Out-Null
        [SpoolerRaw]::EndDocPrinter($hPrinter) | Out-Null

        return @{ success = $true; bytes = $written }

    } finally {
        if ($hPrinter -ne [IntPtr]::Zero) {
            [SpoolerRaw]::ClosePrinter($hPrinter) | Out-Null
        }
    }
}

# ============================================================
# Metodo 3: OpenPrinter con PRINTER_DEFAULTS forzando RAW
# ============================================================
function Print-TryDefaults {
    param([string]$Printer, [byte[]]$Bytes)

    $defaults = New-Object SpoolerRaw+PRINTER_DEFAULTS
    $defaults.DesiredAccess = 0  # PRINTER_ACCESS_USE

    $hPrinter = [IntPtr]::Zero

    $result = [SpoolerRaw]::OpenPrinter($Printer, [ref]$hPrinter, [ref]$defaults)
    if (-not $result) {
        $errCode = [SpoolerRaw]::GetLastError()
        throw "OpenPrinter codigo:$errCode"
    }

    $docInfo = New-Object SpoolerRaw+DOC_INFO_1
    $docInfo.pDocName = "PrinterBridge"
    $docInfo.pOutputFile = $null
    $docInfo.pDatatype = $null

    try {
        $written = 0

        $result = [SpoolerRaw]::StartDocPrinter($hPrinter, 1, [ref]$docInfo)
        if (-not $result) {
            $errCode = [SpoolerRaw]::GetLastError()
            throw "StartDocPrinter codigo:$errCode"
        }

        $result = [SpoolerRaw]::StartPagePrinter($hPrinter)
        if (-not $result) {
            $errCode = [SpoolerRaw]::GetLastError()
            [SpoolerRaw]::EndDocPrinter($hPrinter) | Out-Null
            throw "StartPagePrinter codigo:$errCode"
        }

        $result = [SpoolerRaw]::WritePrinter($hPrinter, $Bytes, $Bytes.Length, [ref]$written)
        if (-not $result) {
            $errCode = [SpoolerRaw]::GetLastError()
            [SpoolerRaw]::EndPagePrinter($hPrinter) | Out-Null
            [SpoolerRaw]::EndDocPrinter($hPrinter) | Out-Null
            throw "WritePrinter codigo:$errCode"
        }

        [SpoolerRaw]::EndPagePrinter($hPrinter) | Out-Null
        [SpoolerRaw]::EndDocPrinter($hPrinter) | Out-Null

        return @{ success = $true; bytes = $written }

    } finally {
        if ($hPrinter -ne [IntPtr]::Zero) {
            [SpoolerRaw]::ClosePrinter($hPrinter) | Out-Null
        }
    }
}

# ============================================================
# Ejecucion principal - intentar metodos en orden
# ============================================================
$lastError = $null

# --- Metodo 1: RAW ---
try {
    $r = Print-TryRaw -Printer $PrinterName -Bytes $data -Datatype "RAW"
    if ($r.success) { Write-Output "OK:$($r.bytes)"; exit 0 }
} catch { $lastError = "RAW: $($_.Exception.Message)" }

# --- Metodo 2: datatype null (Windows elige) ---
try {
    $r = Print-TryRaw -Printer $PrinterName -Bytes $data -Datatype $null
    if ($r.success) { Write-Output "OK:$($r.bytes)"; exit 0 }
} catch { $lastError = "Null: $($_.Exception.Message)" }

# --- Metodo 3: PRINTER_DEFAULTS + datatype null ---
try {
    $r = Print-TryDefaults -Printer $PrinterName -Bytes $data
    if ($r.success) { Write-Output "OK:$($r.bytes)"; exit 0 }
} catch { $lastError = "Defaults: $($_.Exception.Message)" }

# --- Metodo 4: comando `print` de Windows ---
try {
    $printOutput = & print.exe /d:"$PrinterName" $FilePath 2>&1
    $printExit = $LASTEXITCODE
    if ($printExit -eq 0 -or $printExit -eq $null) {
        Write-Output "OK:$fileSize"
        exit 0
    }
    $lastError = "print.exe: exit code $printExit"
} catch { $lastError = "print.exe: $($_.Exception.Message)" }

# Todos fallaron
Write-Output "ERROR:Ningun metodo de impresion funciono."
Write-Output "  Metodo 1 (RAW): $($lastError -split "`n")[0]"
Write-Output "  Metodo 2 (null): $($lastError -split "`n")[1]"
Write-Output "  Metodo 3 (defaults): $($lastError -split "`n")[2]"
Write-Output "  Metodo 4 (print.exe): $($lastError -split "`n")[3]"
Write-Output ""
Write-Output "Verificá que la impresora este encendida, conectada y sin trabajos atascados."
exit 1
