# ============================================================================
# AUTO-COMMENT SCRIPT - Comment Out Files for Migration
# ============================================================================
# This script comments out all .dart files in contacts and profile folders
# that haven't been commented yet.
# ============================================================================

Write-Host "🚀 Starting Auto-Comment Script..." -ForegroundColor Green
Write-Host ""

# Define the folders to process
$folders = @(
    "lib\features\contacts\data\models",
    "lib\features\contacts\data\repositories",
    "lib\features\contacts\presentation\pages",
    "lib\features\contacts\presentation\providers",
    "lib\features\contacts\presentation\widgets",
    "lib\features\profile\data\datasources",
    "lib\features\profile\data\models",
    "lib\features\profile\presentation\pages",
    "lib\features\profile\presentation\providers",
    "lib\features\profile\presentation\widgets"
)

$totalProcessed = 0
$totalSkipped = 0
$totalErrors = 0

foreach ($folder in $folders) {
    $fullPath = Join-Path $PSScriptRoot $folder
    
    if (-not (Test-Path $fullPath)) {
        Write-Host "⚠️  Folder not found: $folder" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "📁 Processing folder: $folder" -ForegroundColor Cyan
    
    $dartFiles = Get-ChildItem -Path $fullPath -Filter "*.dart" -File
    
    foreach ($file in $dartFiles) {
        try {
            $content = Get-Content -Path $file.FullName -Raw
            
            # Check if already commented (starts with /* or has comment header)
            if ($content -match '^\s*/\*' -or $content -match '^//\s*=+\s*$') {
                Write-Host "   ⏭️  Skipped (already commented): $($file.Name)" -ForegroundColor Gray
                $totalSkipped++
                continue
            }
            
            # Extract folder type for header
            $folderType = if ($file.DirectoryName -match "contacts") { "CONTACTS" } else { "PROFILE" }
            $fileName = $file.Name.Replace(".dart", "").ToUpper().Replace("_", " ")
            
            # Create comment header
            $header = @"
// ============================================================================
// $folderType - $fileName - COMMENTED OUT
// ============================================================================
// Team: Uncomment this file tomorrow morning to migrate
// ============================================================================

/*
"@
            
            # Create comment footer
            $footer = @"
*/

// ============================================================================
// END OF COMMENTED CODE
// ============================================================================

"@
            
            # Combine header + content + footer
            $newContent = $header + $content.TrimEnd() + "`n" + $footer
            
            # Write back to file
            Set-Content -Path $file.FullName -Value $newContent -NoNewline
            
            Write-Host "   ✅ Commented: $($file.Name)" -ForegroundColor Green
            $totalProcessed++
            
        } catch {
            Write-Host "   ❌ Error processing $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
            $totalErrors++
        }
    }
    
    Write-Host ""
}

# Summary
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "📊 SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "✅ Files Commented: $totalProcessed" -ForegroundColor Green
Write-Host "⏭️  Files Skipped: $totalSkipped" -ForegroundColor Yellow
Write-Host "❌ Errors: $totalErrors" -ForegroundColor Red
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎉 Script completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Check the MIGRATION_TODO.md file for the complete list" -ForegroundColor White
Write-Host "   2. Tomorrow morning: Uncomment files by removing /* and */" -ForegroundColor White
Write-Host "   3. Migrate to clean architecture" -ForegroundColor White
Write-Host "   4. Test thoroughly" -ForegroundColor White
Write-Host "   5. Delete old files" -ForegroundColor White
Write-Host ""
