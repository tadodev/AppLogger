Write-Host "=== Diagnosing AppLogger Build Issue ===" -ForegroundColor Cyan
Write-Host ""

$projectRoot = Get-Location
Set-Location "$projectRoot\AppLogger"

Write-Host "Building with detailed output to see actual error..." -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Gray

# Build with very verbose output to see the real error
dotnet build -c Release -v detailed

Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Gray
Write-Host ""

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Build succeeded!" -ForegroundColor Green
    
    # Check if DLL was created
    $dllPath = ".\bin\Release\net10.0\AppLogger.dll"
    if (Test-Path $dllPath) {
        Write-Host "✓ AppLogger.dll created at: $dllPath" -ForegroundColor Green
    } else {
        Write-Host "✗ AppLogger.dll NOT found at: $dllPath" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Build FAILED!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common causes:" -ForegroundColor Yellow
    Write-Host "1. ETABSv1.dll reference not found" -ForegroundColor White
    Write-Host "2. EtabsConnect class has compilation errors" -ForegroundColor White
    Write-Host "3. Wrong ETABS path in AppLogger.csproj" -ForegroundColor White
    Write-Host ""
    Write-Host "Check the errors above for details." -ForegroundColor Yellow
}