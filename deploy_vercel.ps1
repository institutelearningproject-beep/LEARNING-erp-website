# LPI - Deploy a Vercel via API
# OBSOLETO — usar deploy_vercel.js (vía "DEPLOY LPI.bat"). Se conserva solo como referencia.
# El token ya no va escrito aquí; se lee de vercel_token.txt (ignorado por git).
$token = (Get-Content (Join-Path $PSScriptRoot "vercel_token.txt") -Raw).Trim()
$projectId = "prj_ZPcK26zmGolKAd0KSwW5D4lPyqd0"
$teamId = "team_Crh14Al7vlA4XukCIsSorIMv"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  LPI - Desplegando a Vercel via API" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Leer archivos
Write-Host "[1/3] Leyendo archivos del proyecto..."
$files = @()

foreach ($filename in @("index.html", "erp.html", "supabase_schema.sql", "vercel.json")) {
    $path = Join-Path $dir $filename
    if (Test-Path $path) {
        $content = Get-Content $path -Raw -Encoding UTF8
        $files += @{
            file = $filename
            data = $content
            encoding = "utf-8"
        }
        Write-Host "  + $filename" -ForegroundColor Green
    }
}

# Crear deployment
Write-Host ""
Write-Host "[2/3] Creando deployment en Vercel..."

$body = @{
    name = "institutelearningproject-project"
    files = $files
    projectSettings = @{
        framework = $null
        outputDirectory = $null
        buildCommand = $null
        devCommand = $null
        installCommand = $null
    }
    target = "production"
} | ConvertTo-Json -Depth 10

$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod `
        -Uri "https://api.vercel.com/v13/deployments?teamId=$teamId" `
        -Method POST `
        -Headers $headers `
        -Body $body `
        -ContentType "application/json"

    Write-Host ""
    Write-Host "[3/3] Deployment creado!" -ForegroundColor Green
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  URL: https://$($response.url)" -ForegroundColor Yellow
    Write-Host "  Estado: $($response.readyState)" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
} catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host $_.ErrorDetails.Message -ForegroundColor Red
}

Write-Host ""
Write-Host "Presiona Enter para cerrar..."
Read-Host
