Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  AppLoggerT Complete Test & Rebuild" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"

# Auto-detect project root (script should be run from solution root)
$projectRoot = Get-Location
Write-Host "Project root: $projectRoot" -ForegroundColor Gray
Write-Host ""

# ============================================================
# Step 0: Verify ETABS Installation
# ============================================================
Write-Host "[Step 0] Verifying ETABS Installation..." -ForegroundColor Yellow
$etabsPaths = @(
    "C:\Program Files\Computers and Structures\ETABS 22\ETABSv1.dll",
    "C:\Program Files (x86)\Computers and Structures\ETABS 22\ETABSv1.dll"
)

$etabsFound = $false
$etabsPath = $null

foreach ($path in $etabsPaths) {
    if (Test-Path $path) {
        Write-Host "  ✓ ETABS found at: $path" -ForegroundColor Green
        $etabsPath = $path
        $etabsFound = $true
        break
    }
}

if (-not $etabsFound) {
    Write-Host "  ✗ ETABS NOT FOUND!" -ForegroundColor Red
    Write-Host "  Cannot proceed without ETABS installation." -ForegroundColor Red
    exit 1
}
Write-Host ""

# ============================================================
# Step 1: Clean Everything
# ============================================================
Write-Host "[Step 1] Cleaning projects..." -ForegroundColor Yellow
Set-Location $projectRoot

dotnet clean | Out-Null

$foldersToDelete = @(
    "$projectRoot\AppLogger\bin",
    "$projectRoot\AppLogger\obj",
    "$projectRoot\PackageTest\bin",
    "$projectRoot\PackageTest\obj"
)

foreach ($folder in $foldersToDelete) {
    if (Test-Path $folder) {
        Remove-Item -Recurse -Force $folder
        Write-Host "  Deleted: $folder" -ForegroundColor Gray
    }
}

Write-Host "  ✓ Clean complete" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 2: Clear NuGet Caches
# ============================================================
Write-Host "[Step 2] Clearing NuGet caches..." -ForegroundColor Yellow
dotnet nuget locals all --clear | Out-Null
Write-Host "  ✓ NuGet cache cleared" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 3: Verify .targets File Content
# ============================================================
Write-Host "[Step 3] Verifying .targets file..." -ForegroundColor Yellow
$targetsFile = "$projectRoot\AppLogger\build\AppLoggerT.targets"

if (Test-Path $targetsFile) {
    $targetsContent = Get-Content $targetsFile -Raw
    
    $checks = @(
        @{Name="CopyEtabsDllToOutput target"; Pattern="CopyEtabsDllToOutput"},
        @{Name="Private=true setting"; Pattern="<Private>true</Private>"},
        @{Name="Copy task"; Pattern="<Copy SourceFiles="}
    )
    
    foreach ($check in $checks) {
        if ($targetsContent -match [regex]::Escape($check.Pattern)) {
            Write-Host "  ✓ $($check.Name) found" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($check.Name) MISSING!" -ForegroundColor Red
            Write-Host "    Your .targets file needs updating!" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  ✗ .targets file not found at: $targetsFile" -ForegroundColor Red
    exit 1
}
Write-Host ""

# ============================================================
# Step 4: Build AppLogger (First, to see real errors)
# ============================================================
Write-Host "[Step 4a] Building AppLogger (checking for errors)..." -ForegroundColor Yellow
Set-Location "$projectRoot\AppLogger"

$buildOutput = dotnet build -c Release 2>&1 | Out-String
Write-Host $buildOutput

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Build successful" -ForegroundColor Green
} else {
    Write-Host "  ✗ Build FAILED! See errors above." -ForegroundColor Red
    Write-Host ""
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "  - ETABSv1 types not found (ETABS reference issue)" -ForegroundColor White
    Write-Host "  - Wrong ETABS path in .csproj" -ForegroundColor White
    exit 1
}
Write-Host ""

# ============================================================
# Step 4b: Pack AppLogger
# ============================================================
Write-Host "[Step 4b] Packing AppLogger..." -ForegroundColor Yellow

$packOutput = dotnet pack -c Release --no-build 2>&1 | Out-String

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Package created successfully" -ForegroundColor Green
} else {
    Write-Host "  ✗ Pack FAILED!" -ForegroundColor Red
    Write-Host $packOutput
    exit 1
}
Write-Host ""

# ============================================================
# Step 5: Inspect Package Contents
# ============================================================
Write-Host "[Step 5] Inspecting package contents..." -ForegroundColor Yellow
$packagePath = "$projectRoot\AppLogger\bin\Release\AppLoggerT.1.0.3.nupkg"

if (Test-Path $packagePath) {
    Write-Host "  ✓ Package found: AppLoggerT.1.0.3.nupkg" -ForegroundColor Green
    
    # Extract package
    $extractPath = "$projectRoot\AppLogger\bin\Release\package_inspect"
    if (Test-Path $extractPath) {
        Remove-Item -Recurse -Force $extractPath
    }
    New-Item -ItemType Directory -Path $extractPath | Out-Null
    
    # Copy and extract
    Copy-Item $packagePath "$extractPath\package.zip"
    Expand-Archive -Path "$extractPath\package.zip" -DestinationPath $extractPath -Force
    
    # Check for .targets files
    $targetsInPackage = "$extractPath\build\AppLoggerT.targets"
    $targetsTransitive = "$extractPath\buildTransitive\AppLoggerT.targets"
    
    if (Test-Path $targetsInPackage) {
        Write-Host "  ✓ build\AppLoggerT.targets found in package" -ForegroundColor Green
        
        $content = Get-Content $targetsInPackage -Raw
        if ($content -match "CopyEtabsDllToOutput") {
            Write-Host "  ✓ .targets contains CopyEtabsDllToOutput" -ForegroundColor Green
        } else {
            Write-Host "  ✗ .targets MISSING CopyEtabsDllToOutput!" -ForegroundColor Red
            Write-Host "    Package has OLD .targets file!" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✗ build\AppLoggerT.targets NOT in package!" -ForegroundColor Red
    }
    
    if (Test-Path $targetsTransitive) {
        Write-Host "  ✓ buildTransitive\AppLoggerT.targets found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ buildTransitive\AppLoggerT.targets NOT found" -ForegroundColor Red
    }
} else {
    Write-Host "  ✗ Package not found!" -ForegroundColor Red
    Write-Host "    Expected: $packagePath" -ForegroundColor Red
    exit 1
}
Write-Host ""

# ============================================================
# Step 6: Update PackageTest
# ============================================================
Write-Host "[Step 6] Updating PackageTest..." -ForegroundColor Yellow
Set-Location "$projectRoot\PackageTest"

# Remove old package reference
Write-Host "  Removing old package reference..." -ForegroundColor Gray
dotnet remove package AppLoggerT 2>&1 | Out-Null

# Add new package from local source
Write-Host "  Adding package from local source..." -ForegroundColor Gray
dotnet add package AppLoggerT --version 1.0.3 --source "$projectRoot\AppLogger\bin\Release" 2>&1 | Out-Null

Write-Host "  ✓ Package reference updated" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 7: Build PackageTest (VERBOSE)
# ============================================================
Write-Host "[Step 7] Building PackageTest..." -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

$buildOutput = dotnet build -v normal 2>&1 | Out-String
Write-Host $buildOutput

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Build successful" -ForegroundColor Green
} else {
    Write-Host "  ✗ Build FAILED!" -ForegroundColor Red
}
Write-Host ""

# ============================================================
# Step 8: Check Build Messages
# ============================================================
Write-Host "[Step 8] Analyzing build output..." -ForegroundColor Yellow

$messages = @(
    @{Name="ETABS detected"; Pattern="\[AppLoggerT\] ETABS detected"},
    @{Name="Copy started"; Pattern="Copying ETABS DLL|Copying ETABSv1.dll"},
    @{Name="Copy completed"; Pattern="Copy completed successfully|Copied ETABSv1.dll to"}
)

foreach ($msg in $messages) {
    if ($buildOutput -match $msg.Pattern) {
        Write-Host "  ✓ $($msg.Name)" -ForegroundColor Green
        # Show the actual message
        $matches = [regex]::Matches($buildOutput, ".*$($msg.Pattern).*")
        foreach ($match in $matches) {
            Write-Host "    └─ $($match.Value.Trim())" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ✗ $($msg.Name) NOT found" -ForegroundColor Red
    }
}
Write-Host ""

# ============================================================
# Step 9: CRITICAL - Verify DLL in Output
# ============================================================
Write-Host "[Step 9] Verifying ETABSv1.dll in output directory..." -ForegroundColor Yellow
$outputDll = "$projectRoot\PackageTest\bin\Debug\net10.0\ETABSv1.dll"

if (Test-Path $outputDll) {
    Write-Host "  ✅ SUCCESS! ETABSv1.dll found!" -ForegroundColor Green
    $file = Get-Item $outputDll
    Write-Host "    Path: $($file.FullName)" -ForegroundColor Gray
    Write-Host "    Size: $($file.Length) bytes" -ForegroundColor Gray
    Write-Host "    Modified: $($file.LastWriteTime)" -ForegroundColor Gray
    
    # Compare with source
    $sourceDll = Get-Item $etabsPath
    if ($file.Length -eq $sourceDll.Length) {
        Write-Host "  ✓ DLL size matches source" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ DLL size differs from source" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ❌ FAILED! ETABSv1.dll NOT in output!" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Expected location: $outputDll" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Contents of output directory:" -ForegroundColor Yellow
    $outputDir = "$projectRoot\PackageTest\bin\Debug\net10.0"
    if (Test-Path $outputDir) {
        Get-ChildItem $outputDir | Select-Object Name, Length | Format-Table -AutoSize
    } else {
        Write-Host "  Output directory doesn't exist!" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "  TROUBLESHOOTING:" -ForegroundColor Yellow
    Write-Host "  1. Check if .targets file is being loaded" -ForegroundColor White
    Write-Host "  2. Verify ETABS path is detected correctly" -ForegroundColor White
    Write-Host "  3. Ensure Copy task is executing" -ForegroundColor White
}
Write-Host ""

# ============================================================
# Step 10: Run the Application (if DLL found)
# ============================================================
if (Test-Path $outputDll) {
    Write-Host "[Step 10] Running application..." -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    Set-Location "$projectRoot\PackageTest"
    dotnet run
    
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
} else {
    Write-Host "[Step 10] Skipping run - DLL not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Complete" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan