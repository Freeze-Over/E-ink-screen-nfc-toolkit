param(
    [string]$Sdk = "D:\Android\Sdk",
    [string]$JavaHome = "C:\Program Files\Java\jdk-21",
    [string]$BuildTools = "36.0.0",
    [string]$Platform = "android-37.0",
    [string]$OutApk = "QPollLab-local.apk"
)

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $project

$bt = Join-Path $Sdk "build-tools\$BuildTools"
$aapt2 = Join-Path $bt "aapt2.exe"
$zipalign = Join-Path $bt "zipalign.exe"
$apksigner = Join-Path $bt "apksigner.bat"
$d8jar = Join-Path $bt "lib\d8.jar"
$androidJar = Join-Path $Sdk "platforms\$Platform\android.jar"
$java = Join-Path $JavaHome "bin\java.exe"
$javac = Join-Path $JavaHome "bin\javac.exe"
$jar = Join-Path $JavaHome "bin\jar.exe"
$keytool = Join-Path $JavaHome "bin\keytool.exe"

$build = Join-Path $project "build"
if (Test-Path $build) { Remove-Item -Recurse -Force $build }
New-Item -ItemType Directory -Path $build | Out-Null
$classes = Join-Path $build "classes"
$dexDir = Join-Path $build "dex"
$gen = Join-Path $build "gen"
New-Item -ItemType Directory -Path $classes, $dexDir, $gen | Out-Null

# extract Shizuku AAR classes.jar
$libJars = @()
foreach ($aar in Get-ChildItem (Join-Path $project "libs") -Filter "*-13.1.5.aar") {
    $target = Join-Path $build ($aar.BaseName + ".jar")
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($aar.FullName)
    try {
        $entry = $zip.GetEntry("classes.jar")
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
    } finally { $zip.Dispose() }
    $libJars += $target
}
$libJars += @(Get-ChildItem (Join-Path $project "libs") -Filter "*.jar" | ForEach-Object { $_.FullName })

Write-Host "[1/6] aapt2 compile"
& $aapt2 compile --dir res -o (Join-Path $build "res.zip")
if ($LASTEXITCODE -ne 0) { throw "aapt2 compile failed" }

Write-Host "[2/6] aapt2 link"
& $aapt2 link -o (Join-Path $build "base.apk") -I $androidJar --manifest AndroidManifest.xml -A assets --java $gen (Join-Path $build "res.zip")
if ($LASTEXITCODE -ne 0) { throw "aapt2 link failed" }

Write-Host "[3/6] javac"
$srcs = @(Get-ChildItem -Recurse -Filter *.java -Path src, $gen | ForEach-Object { $_.FullName })
$cp = ($androidJar + ";" + ($libJars -join ";"))
& $javac -encoding UTF-8 --release 8 -Xlint:-options -classpath $cp -d $classes @srcs
if ($LASTEXITCODE -ne 0) { throw "javac failed" }

Write-Host "[4/6] d8"
& $jar cf (Join-Path $build "classes.jar") -C $classes .
& $java -cp $d8jar com.android.tools.r8.D8 --release --min-api 26 --lib $androidJar --output $dexDir (Join-Path $build "classes.jar") @libJars
if ($LASTEXITCODE -ne 0) { throw "d8 failed" }

Write-Host "[5/6] package"
$unsigned = Join-Path $build "unsigned.apk"
Copy-Item (Join-Path $build "base.apk") $unsigned -Force
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($unsigned, "Update")
try {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $dexDir "classes.dex"), "classes.dex",
        [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
} finally { $zip.Dispose() }

$aligned = Join-Path $build "aligned.apk"
& $zipalign -f 4 $unsigned $aligned
if ($LASTEXITCODE -ne 0) { throw "zipalign failed" }

Write-Host "[6/6] sign"
$ks = Join-Path $build "qpoll.keystore"
if (-not (Test-Path $ks)) {
    & $keytool -genkeypair -keystore $ks -storepass android -keypass android `
        -alias qpolllab -keyalg RSA -keysize 2048 -validity 10000 `
        -dname "CN=QPoll Lab Local" -noprompt | Out-Null
}
$outPath = Join-Path $project $OutApk
& $apksigner sign --ks $ks --ks-pass pass:android --key-pass pass:android --ks-key-alias qpolllab --out $outPath $aligned
if ($LASTEXITCODE -ne 0) { throw "apksigner failed" }
Write-Host "OK: $outPath"
