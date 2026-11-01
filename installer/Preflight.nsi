; =============================================================================
;  PreflightSetup.exe -- installer for Audio-Video Preflight
;  Built by Publish-Release.ps1:  makensis -DVERSION=x.y.z -DOUTFILE=... installer/Preflight.nsi
;
;  Installs for the current user only, into %LOCALAPPDATA%\Programs: no admin
;  rights, and the folder stays writable so Preflight can update itself.
; =============================================================================
Unicode true
!include "MUI2.nsh"
!include "FileFunc.nsh"

!ifndef VERSION
  !error "Pass the version: makensis -DVERSION=5.6.1 Preflight.nsi"
!endif
!ifndef OUTFILE
  !define OUTFILE "PreflightSetup.exe"
!endif

!define APPNAME     "Audio-Video Preflight"
!define PUBLISHER   "carl-gian"
!define REPO_URL    "https://github.com/carl-gian/Project-Preflight"
!define UNINST_KEY  "Software\Microsoft\Windows\CurrentVersion\Uninstall\AudioVideoPreflight"
!define SHORTCUT    "Audio-Video Preflight.lnk"   ; same name the app's own Settings switch uses

Name "${APPNAME}"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\${APPNAME}"
InstallDirRegKey HKCU "Software\${APPNAME}" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "${APPNAME} ${VERSION}"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName"     "${APPNAME}"
VIAddVersionKey "ProductVersion"  "${VERSION}"
VIAddVersionKey "FileVersion"     "${VERSION}"
VIAddVersionKey "FileDescription" "${APPNAME} installer"
VIAddVersionKey "CompanyName"     "${PUBLISHER}"
VIAddVersionKey "LegalCopyright"  "${PUBLISHER}"

; ----- Look: Steward artwork and plain wording --------------------------------
!define MUI_ICON   "preflight.ico"
!define MUI_UNICON "preflight.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP   "wizard.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "wizard.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP   "header.bmp"
!define MUI_HEADERIMAGE_UNBITMAP "header.bmp"
!define MUI_ABORTWARNING
!define MUI_ABORTWARNING_TEXT "Stop installing ${APPNAME}?"
!define MUI_COMPONENTSPAGE_NODESC

!define MUI_WELCOMEPAGE_TITLE "Install ${APPNAME}"
!define MUI_WELCOMEPAGE_TEXT "Preflight walks the AV operator through the meeting set-up, checks the hardware, then opens OBS, Zoom and Meeting Media Manager in their places.$\r$\n$\r$\nIt installs for you only and doesn't need administrator rights. Your settings are kept if Preflight is already on this laptop.$\r$\n$\r$\nVersion ${VERSION}."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!define MUI_PAGE_HEADER_TEXT "Choose options"
!define MUI_PAGE_HEADER_SUBTEXT "You can change these later in Preflight's Settings."
!define MUI_COMPONENTSPAGE_TEXT_TOP "Pick what to add. Preflight itself is always installed."
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_TITLE "Preflight is ready"
!define MUI_FINISHPAGE_TEXT "It's in the Start menu as ${APPNAME}. New versions install by themselves when Preflight starts."
!define MUI_FINISHPAGE_RUN "$INSTDIR\Preflight.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Open Preflight now"
!define MUI_FINISHPAGE_LINK "About Preflight"
!define MUI_FINISHPAGE_LINK_LOCATION "${REPO_URL}"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ----- Install ----------------------------------------------------------------
Section "Preflight" SecApp
  SectionIn RO
  SetOutPath "$INSTDIR"
  File "..\Preflight.ps1"
  File "..\Preflight.exe"
  SetOutPath "$INSTDIR\media"
  File /r /x ".DS_Store" /x "Thumbs.db" /x "desktop.ini" "..\media\*.*"
  SetOutPath "$INSTDIR"

  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortcut "$SMPROGRAMS\${SHORTCUT}" "$INSTDIR\Preflight.exe" "" "$INSTDIR\Preflight.exe" 0 SW_SHOWNORMAL "" "${APPNAME}"

  WriteRegStr HKCU "Software\${APPNAME}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayName"     "${APPNAME}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion"  "${VERSION}"
  WriteRegStr HKCU "${UNINST_KEY}" "Publisher"       "${PUBLISHER}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon"     "$INSTDIR\Preflight.exe"
  WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "URLInfoAbout"    "${REPO_URL}"
  WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" "$0"
SectionEnd

Section "Desktop shortcut" SecDesktop
  CreateShortcut "$DESKTOP\${SHORTCUT}" "$INSTDIR\Preflight.exe" "" "$INSTDIR\Preflight.exe" 0 SW_SHOWNORMAL "" "${APPNAME}"
SectionEnd

Section "Start Preflight when Windows starts" SecStartup
  CreateShortcut "$SMSTARTUP\${SHORTCUT}" "$INSTDIR\Preflight.exe" "" "$INSTDIR\Preflight.exe" 0 SW_SHOWNORMAL "" "${APPNAME}"
SectionEnd

; ----- Uninstall --------------------------------------------------------------
; Deletes only what Preflight puts there (never the whole folder recursively),
; so a folder chosen by hand, like the Desktop, is safe.
Section "Uninstall"
  Delete "$INSTDIR\Preflight.ps1"
  Delete "$INSTDIR\Preflight.exe"
  Delete "$INSTDIR\launcher.log"
  Delete "$INSTDIR\launcher.log.old"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR\media"
  RMDir "$INSTDIR"

  Delete "$SMPROGRAMS\${SHORTCUT}"
  Delete "$DESKTOP\${SHORTCUT}"
  Delete "$SMSTARTUP\${SHORTCUT}"
  DeleteRegKey HKCU "${UNINST_KEY}"
  DeleteRegKey HKCU "Software\${APPNAME}"

  ; Settings belong to the operator: kept unless they say otherwise. Silent
  ; uninstalls (/S) keep them too.
  MessageBox MB_YESNO|MB_ICONQUESTION|MB_DEFBUTTON2 "Also remove your Preflight settings and window layout?$\r$\n$\r$\nChoose No to keep them for next time." /SD IDNO IDNO keep
    RMDir /r "$DOCUMENTS\Preflight Settings"
    RMDir /r "$LOCALAPPDATA\AV-Preflight"
  keep:
SectionEnd
