# SoftwareDownloader
Download latest versions of different software installers using PowerShell script

Set all necessary software sources in .xml file and use .ps1 script to download file according to your settings.

Script tries to compare local and remote file last-modified date. When a new version is detected, it tries to download the installer.

Each entry in XML file requires a few parameters - start with browsing existing configuration.
Key parameters are:
- URL
- Method

Currently 3 methods are available:
- DirectURL - script tries to check directly the file from the URL
- FindOnGithub - script tries to detect latest stable version on GitHub
- FindOnWebsite - script tries to find specific file name pattern on any website