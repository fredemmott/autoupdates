$baseline = (Get-Content 'src/vcpkg-configuration.json' | ConvertFrom-Json -AsHashTable)["default-registry"].baseline
git clone https://github.com/microsoft/vcpkg.git
cd vcpkg
git reset --hard $baseline
./bootstrap-vcpkg.bat
cd ..

@"
<Project>
 <Import Project="`$(MSBuildThisFileDirectory)vcpkg\scripts\buildsystems\msbuild\vcpkg.props" />
</Project>
"@ | Set-Content Directory.Build.props
@"
<Project>
 <Import Project="`$(MSBuildThisFileDirectory)vcpkg\scripts\buildsystems\msbuild\vcpkg.targets" />
</Project>
"@ | Set-Content Directory.Build.targets
