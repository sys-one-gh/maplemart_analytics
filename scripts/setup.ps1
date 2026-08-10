# Cross-platform bootstrap for native Windows (PowerShell), no WSL required.
# macOS / Linux / WSL: use scripts/setup.sh instead.
#
# Usage:
#   .\scripts\setup.ps1
#   .\scripts\setup.ps1 -Branch feature/python
#   .\scripts\setup.ps1 -SkipData
#   .\scripts\setup.ps1 -WithAI

param(
    [string]$Branch = "",
    [switch]$SkipData,
    [switch]$WithAI
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
$RepoRoot = Get-Location

function Log($msg)  { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "    ok: $msg" -ForegroundColor Green }
function WarnMsg($msg) { Write-Host "    warn: $msg" -ForegroundColor Yellow }
function Die($msg)  { Write-Host "    error: $msg" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------------------
Log "Checking Docker"
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    WarnMsg "Docker not found - attempting install via winget"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
        WarnMsg "Launch Docker Desktop once from the Start Menu to finish setup, then re-run this script."
        exit 1
    } else {
        Die "winget not available. Install Docker Desktop manually from docker.com, then re-run this script."
    }
}
try { docker info | Out-Null } catch { Die "Docker is installed but not running. Start Docker Desktop and re-run this script." }
Ok "Docker is installed and running"

# ---------------------------------------------------------------------------
Log "Checking Python 3"
$py = $null
foreach ($cand in @("python", "python3")) {
    if (Get-Command $cand -ErrorAction SilentlyContinue) {
        $verOk = & $cand -c "import sys; print(sys.version_info>=(3,9))" 2>$null
        if ($verOk -eq "True") { $py = $cand; break }
    }
}
if (-not $py) {
    WarnMsg "Python 3.9+ not found - attempting install via winget"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements
        $py = "python"
    } else {
        Die "Could not find or install Python 3.9+. Install it manually, then re-run this script."
    }
}
Ok (& $py --version)

# ---------------------------------------------------------------------------
Log "Checking Microsoft ODBC Driver 18 for SQL Server (required by pyodbc)"
$odbcOk = Get-OdbcDriver -Name "ODBC Driver 18 for SQL Server" -ErrorAction SilentlyContinue
if (-not $odbcOk) {
    WarnMsg "ODBC Driver 18 not found - attempting install via winget"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install -e --id Microsoft.msodbcsql.18 --accept-source-agreements --accept-package-agreements
    } else {
        Die "winget not available. Install the ODBC Driver 18 manually: https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server"
    }
}
Ok "ODBC Driver 18 for SQL Server is available"

# ---------------------------------------------------------------------------
Log "Checking .env"
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    function New-RandomPassword {
        -join ((48..57)+(65..90)+(97..122) | Get-Random -Count 20 | ForEach-Object {[char]$_}) + "Aa1!"
    }
    $saPw = New-RandomPassword
    $pbiPw = New-RandomPassword
    (Get-Content ".env") `
        -replace '^SA_PASSWORD=.*', "SA_PASSWORD=$saPw" `
        -replace '^POWERBI_READER_PASSWORD=.*', "POWERBI_READER_PASSWORD=$pbiPw" |
        Set-Content ".env"
    Ok "Generated .env with random SA/Power BI passwords (never committed - see .gitignore)"
} else {
    Ok ".env already exists, leaving it as-is"
}
Get-Content ".env" | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
    }
}
$SaPassword = [System.Environment]::GetEnvironmentVariable("SA_PASSWORD")

# ---------------------------------------------------------------------------
Log "Checking for port conflicts"

function Test-PortInUse($port) {
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    return [bool]$conn
}

function Find-FreePort($startPort) {
    $port = $startPort
    $tries = 0
    while (Test-PortInUse $port) {
        $port++
        $tries++
        if ($tries -ge 50) { Die "Could not find a free port near $startPort after 50 tries" }
    }
    return $port
}

$sqlserverRunning = (docker ps --format '{{.Names}}' 2>$null) -contains "maplemart-sqlserver"
$ollamaRunning = (docker ps --format '{{.Names}}' 2>$null) -contains "maplemart-ollama"

$curSqlPort = [System.Environment]::GetEnvironmentVariable("SQLSERVER_PORT")
if (-not $curSqlPort) { $curSqlPort = 1433 }
$curOllamaPort = [System.Environment]::GetEnvironmentVariable("OLLAMA_PORT")
if (-not $curOllamaPort) { $curOllamaPort = 11434 }

if (-not $sqlserverRunning -and (Test-PortInUse $curSqlPort)) {
    $newPort = Find-FreePort $curSqlPort
    WarnMsg "Port $curSqlPort is already in use by another process - using $newPort for SQL Server instead"
    $curSqlPort = $newPort
}
if (-not $ollamaRunning -and (Test-PortInUse $curOllamaPort)) {
    $newPort = Find-FreePort $curOllamaPort
    WarnMsg "Port $curOllamaPort is already in use by another process - using $newPort for Ollama instead"
    $curOllamaPort = $newPort
}

$envContent = Get-Content ".env"
if ($envContent -match '^SQLSERVER_PORT=') {
    $envContent = $envContent -replace '^SQLSERVER_PORT=.*', "SQLSERVER_PORT=$curSqlPort"
} else {
    $envContent += "SQLSERVER_PORT=$curSqlPort"
}
if ($envContent -match '^OLLAMA_PORT=') {
    $envContent = $envContent -replace '^OLLAMA_PORT=.*', "OLLAMA_PORT=$curOllamaPort"
} else {
    $envContent += "OLLAMA_PORT=$curOllamaPort"
}
$envContent = $envContent -replace '^DB_SERVER=.*', "DB_SERVER=localhost,$curSqlPort"
$envContent = $envContent -replace '^OLLAMA_HOST=.*', "OLLAMA_HOST=http://localhost:$curOllamaPort"
$envContent | Set-Content ".env"
Get-Content ".env" | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
    }
}
Ok "SQL Server -> host port $curSqlPort, Ollama -> host port $curOllamaPort"

# ---------------------------------------------------------------------------
if ($Branch -ne "") {
    Log "Checking out branch: $Branch"
    git fetch origin $Branch 2>$null
    git checkout $Branch 2>$null
    if ($LASTEXITCODE -ne 0) { git checkout -b $Branch "origin/$Branch" }
    Ok "On branch $(git branch --show-current)"
}

# ---------------------------------------------------------------------------
Log "Starting containers (sqlserver + ollama)"
docker compose up -d
Ok "docker compose up -d done"

Log "Waiting for SQL Server to accept connections"
$sqlcmdBin = "/opt/mssql-tools18/bin/sqlcmd"
$sqlcmdExtra = "-C", "-No"
$found = $false
for ($i = 0; $i -lt 12; $i++) {
    docker exec maplemart-sqlserver test -x $sqlcmdBin 2>$null
    if ($LASTEXITCODE -eq 0) { $found = $true; break }
    $sqlcmdBin = "/opt/mssql-tools/bin/sqlcmd"; $sqlcmdExtra = @()
    docker exec maplemart-sqlserver test -x $sqlcmdBin 2>$null
    if ($LASTEXITCODE -eq 0) { $found = $true; break }
    Start-Sleep -Seconds 5
}

$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    docker exec maplemart-sqlserver $sqlcmdBin -S localhost -U sa -P $SaPassword @sqlcmdExtra -Q "SELECT 1" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Seconds 5
}
if (-not $ready) { Die "SQL Server did not become ready in time. Check: docker logs maplemart-sqlserver" }
Ok "SQL Server is ready"

function Run-Sql($file) {
    Write-Host "    -> $file"
    $pbiPw = [System.Environment]::GetEnvironmentVariable("POWERBI_READER_PASSWORD")
    if (-not $pbiPw) { $pbiPw = "ChangeMePBI!2026" }
    docker exec maplemart-sqlserver $sqlcmdBin -S localhost -U sa -P $SaPassword @sqlcmdExtra -v PowerBiPassword=$pbiPw -b -i "/workspace/$file"
    if ($LASTEXITCODE -ne 0) { Die "Script failed: $file" }
}

Log "Running database scripts (schema)"
$schemaScripts = @(
    "Database/DatabaseCreation/01_CreateDatabase.sql",
    "Database/Tables/02_CreateReferenceTables.sql",
    "Database/Tables/03_CreateOperationalTables.sql",
    "Database/Tables/04_CreateAnalyticalTables.sql",
    "Database/Constraints/05_CreateConstraints.sql",
    "Database/Indexes/06_CreateIndexes.sql",
    "Database/Functions/08_CreateFunctions.sql",
    "Database/Views/07_CreateViews.sql",
    "Database/StoredProcedures/09_CreateStoredProcedures.sql",
    "Database/Security/11_CreateSecurity.sql"
)
foreach ($f in $schemaScripts) { Run-Sql $f }
Ok "Schema created"

if (-not $SkipData) {
    Log "Preparing Python virtualenv"
    & $py -m venv .venv
    & .\.venv\Scripts\Activate.ps1
    pip install --quiet --upgrade pip
    pip install --quiet -r Python/requirements.txt
    Ok "Python dependencies installed into .venv"

    $datasetFiles = Get-ChildItem "Dataset" -File | Where-Object { $_.Name -ne ".gitkeep" }
    if (-not $datasetFiles) {
        Log "Dataset/ is empty - generating synthetic placeholder CSVs"
        python Python/generate_synthetic_dataset.py
        Ok "Synthetic dataset generated in Dataset/"
    } else {
        Ok "Dataset/ already has data, skipping generation"
    }

    Log "Loading dataset into SQL Server"
    Run-Sql "Database/DatabaseCreation/10_LoadDataset.sql"
    Ok "Dataset loaded"

    Log "Running validation checks"
    Run-Sql "Database/Validation/12_Validation.sql"
}

if ($WithAI) {
    $model = [System.Environment]::GetEnvironmentVariable("OLLAMA_MODEL")
    if (-not $model) { $model = "mistral" }
    Log "Pulling Ollama model: $model (this can take a while)"
    docker exec maplemart-ollama ollama pull $model
    Ok "Ollama model ready"
} else {
    WarnMsg "Skipped pulling the Ollama model. Run: docker exec maplemart-ollama ollama pull mistral  (or re-run with -WithAI)"
}

Log "Done"
Write-Host ""
Write-Host "  SQL Server : localhost,$curSqlPort  (user 'sa', password in .env)"
Write-Host "  Ollama     : http://localhost:$curOllamaPort"
Write-Host "  Python venv: .venv\Scripts\Activate.ps1"
Write-Host ""
Write-Host "  Your branch: $(git branch --show-current)"
Write-Host "  When you're ready to upload your part:"
Write-Host "    .\scripts\push_my_work.ps1 'short description of what you did'"
Write-Host ""
