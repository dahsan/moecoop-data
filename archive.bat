@echo off
dub build -a x86_64 -b release
powershell -Command Compress-Archive -Path fukuro.exe, LICENSE, README.md, resource, doc, libcurl.dll -DestinationPath moecoop.zip
