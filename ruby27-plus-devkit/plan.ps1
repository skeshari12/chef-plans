$pkg_name="ruby27-plus-devkit"
$pkg_origin="chef"
$pkg_version="2.7.0"
$pkg_revision="1"
$pkg_maintainer="maintainers@chef.io"
$pkg_license=@("Apache-2.0")
$pkg_source="s3://habitat-buildkite-cache-chef-prod/rubyinstaller-devkit-${pkg_version}-${pkg_revision}-x64.exe"
$pkg_shasum="af72cdb6afe2f5e04cb58bb11234c0d3d107d449482141b72dd8430a2ed1fe98"
$pkg_bin_dirs=@(
    "bin"
    "/msys64/mingw64/bin"
    "/msys64/usr/bin"
)
$pkg_build_deps=("core/aws-cli")
$ruby_abi_version = [RegEx]::Replace($pkg_version, "\.\d+$", ".0")

function Invoke-SetupEnvironment {
    Push-RuntimeEnv -IsPath "GEM_PATH" "$pkg_prefix/lib/ruby/gems/$ruby_abi_version"
}

function Invoke-Download {
    Push-Location $HAB_CACHE_SRC_PATH
    try {
        if ((Test-Path $pkg_filename) -and $pkg_shasum) {
            Write-BuildLine "Found previous file '$pkg_filename', attempting to re-use"
            if (_verify_file $pkg_filename $pkg_shasum) {
                Write-BuildLine "Using cached and verified '$pkg_filename'"
                return
            } else {
                Write-BuildLine "Clearing previous '$pkg_filename' file and re-attempting download"
                Remove-Item $pkg_filename -Force
            }
        }

        Write-BuildLine "Downloading '$pkg_source' to '$pkg_filename'"
        aws s3 cp $pkg_source $pkg_filename
        Write-BuildLine "Downloaded '$pkg_filename'"
    } finally {
        Pop-Location
    }
}

function Invoke-Unpack {
    Write-BuildLine "Unpacking $pkg_filename"
    Start-Process "$HAB_CACHE_SRC_PATH/$pkg_filename" -Wait -ArgumentList "/SP- /NORESTART /VERYSILENT /SUPPRESSMSGBOXES /NOPATH /DIR=$HAB_CACHE_SRC_PATH/$pkg_dirname"
}

function Invoke-Build {
    Write-BuildLine "** Launch msys2 once in order to initialize the install"
    Invoke-Expression -Command "$HAB_CACHE_SRC_PATH/$pkg_dirname/msys64/msys2_shell.cmd -defterm -no-start" -Verbose
    # The path separator in the -ILike value below must be a backslash for it will match properly
    Get-Process | Where-Object Path -ILike "$HAB_CACHE_SRC_PATH\$pkg_dirname\*" | Stop-Process -Force
}

function Invoke-Install {
    Write-BuildLine "** Copying files to the package location"
    Copy-Item "$HAB_CACHE_SRC_PATH/$pkg_dirname/*" "$pkg_prefix" -Recurse -Force

    Write-BuildLine "** Include git because why not at this point."
    Invoke-Expression -Command "$pkg_prefix/bin/ridk.cmd exec pacman -S --noconfirm git" -Verbose
}

function Invoke-After {
    Write-BuildLine "** Clean-up unnecessary cached items"
    Get-ChildItem $pkg_prefix/lib/ruby/gems/$ruby_abi_version/gems -Filter "spec" -Recurse | Remove-Item -Recurse -Force
    Get-ChildItem $pkg_prefix/lib/ruby/gems/$ruby_abi_version/cache -Recurse | Remove-Item -Recurse -Force
    Get-ChildItem $pkg_prefix -Filter "unins000.*" | Remove-Item -Recurse -Force
    Get-ChildItem $pkg_prefix -Filter "share" | Remove-Item -Recurse -Force   
}

function Invoke-End {
    Write-BuildLine "** Remove RubyInstaller installer from system state"
    Start-Process "$HAB_CACHE_SRC_PATH/$pkg_dirname/unins000.exe" -Wait -ArgumentList "/SILENT /NORESTART"
}