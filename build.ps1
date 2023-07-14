# This build script only test for 3.7.3

$optimize_flag = "Debug"

$editor_list_file = "$HOME/.Cocos/profiles/editor.json"
if (!(Test-Path $editor_list_file -PathType Leaf)) {
    Write-Host "The cocos creator not intalled, please install first"
    Pause
    return
}

$strJson = Get-Content $editor_list_file -raw

$config = ConvertFrom-Json $strJson

if (!$config.editor || !$config.editor.Creator3D) {
    Write-Host "This script only support cocos creator 3.x"
    Pause
    return
}
$editor_list = $config.editor.Creator3D
if ($editor_list.Count -lt 1) {
    Write-Host "No editor installed"
    return
}
Write-Host "Intalled Cocos Creator Editor list: "

for ($i = 0; $i -lt $editor_list.Count; $i++) {
    $editor_info = $editor_list
    Write-Host "$($i + 1). version: $($editor_info.version), path: $($editor_info.file)"
}

$engine_sel = 1

if ($editor_list.Count -gt 1) {
    Write-Host "please input cocos creator version: " -NoNewLine
    $input_text = Read-Host

    if(![Int32]::TryParse($input_text, [ref]$engine_sel)) {
        Write-Host "Invalid input"
        Pause
        return
    }
    
    if ($engine_sel -lt 1 -or $engine_sel -gt $editor_list.Count) {
        Write-Host "Selected index out of range"
        Pause
        return
    }
}

function mkdirs($path) {
    New-Item $path -ItemType Directory 1>$null
}

$engine_ver = $editor_list[$engine_sel - 1].version

$editorPath = $editor_list[$engine_sel - 1].file
$eidtorDir = Split-Path -parent $editorPath
$sourceEngineRoot = Join-Path $eidtorDir 'resources/resources/3d/engine'
$sourceNativeDir = Join-Path $sourceEngineRoot 'native/*'
$sourceCMakeTemplate = Join-Path $sourceEngineRoot 'templates/cmake/*'

$myRoot = $PSScriptRoot

# paths
$engineRoot = Join-Path $myRoot 'custom-native'
$cmakeTemplateDir = Join-Path $engineRoot 'templates/cmake/'
if (!(Test-Path $cmakeTemplateDir -PathType Container)) {
    mkdirs $cmakeTemplateDir
}
$nativeDir = Join-Path $engineRoot "$engine_ver/"
if(!(Test-Path $nativeDir -PathType Container)) {
    mkdirs $nativeDir
}
$simulatorDir = Join-Path $nativeDir 'tools/simulator/frameworks/runtime-src/'

# copy cmake modules
Copy-Item -Path $sourceCMakeTemplate -Destination "$cmakeTemplateDir" -Recurse -Force

# checkout from git
# if (!(Test-Path $engineDir -PathType Container)) {
#     git clone --branch $engine_ver https://github.com/cocos/cocos-engine $engineDir
# }
# git -C $engineDir checkout $engine_ver
# $external_ver = $(ConvertFrom-Json $(Get-Content $(Join-Path $nativeDir 'external-config.json') -raw)).from.checkout

# $externalDir = Join-Path $nativeDir 'external'
# if (!(Test-Path $externalDir -PathType Container)) {
#     git clone https://github.com/cocos/cocos-engine-external $externalDir
# }
# git -C $externalDir checkout $external_ver

# copy engine-native from local
if (!(Test-Path "$nativeDir/CMakeLists.txt" -PathType Leaf)) {
    Copy-Item "$sourceNativeDir" "$nativeDir" -Recurse -Force
}

$simulatorReleaseDir = Join-Path $nativeDir 'simulator/Release'
if (!(Test-Path $simulatorReleaseDir)) {
    mkdirs $simulatorReleaseDir
}

# patch
$patch = Join-Path $myRoot 'native-patch\*'
Copy-Item -Path $patch -Destination "$nativeDir" -Recurse -Force

# build
Set-Location $simulatorDir
if (!$IsMacOS) {
    cmake -B build
}
else {
    cmake -B build -GXcode
}

$target_name = if(!$IsMacOS) {'SimulatorApp-Win32'} else {'SimulatorApp-Mac'}

cmake --build build --config $optimize_flag --target $target_name

Set-Location $myRoot

# update link
$simulatorBin = Join-Path $simulatorDir 'build/Debug/*'
$simulatorDist = Join-Path $myRoot "simulator/$optimize_flag/"

if (!(Test-Path $simulatorDist -PathType Container)) {
    mkdirs $simulatorDist
}

Copy-Item -Path $simulatorBin -Destination $simulatorDist -Recurse -Force

$simulatorLinkDest = Join-Path $nativeDir 'simulator/Release'
if ((Test-Path $simulatorLinkDest -PathType Container)) {
    Remove-Item -Path $simulatorLinkDest -Recurse -Force
}

New-Item -Path $simulatorLinkDest -ItemType Junction -Value $simulatorDist

# ------ link source engine native simulator
Write-Host "Linking source dir"
$simulatorLinkDest = Join-Path $sourceEngineRoot 'native/simulator/Release'
if (Test-Path $simulatorLinkDest -PathType Container) {
    $simulatorBak = "${simulatorLinkDest}-bak"
    if (Test-Path $simulatorBak -PathType Container) {
        Remove-Item -Path $simulatorLinkDest -Recurse -Force
    }
    else {
        Move-Item $simulatorLinkDest $simulatorBak
    }
}
New-Item -Path $simulatorLinkDest -ItemType Junction -Value $simulatorDist

# 
Write-Host "build simulator done, you can locate native engine to: $nativeDir in cocos creator editor"
Pause

