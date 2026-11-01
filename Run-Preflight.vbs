' =============================================================================
'  Audio-Video Preflight Launcher -- WTLC Edition v5.4
'  Launches preflight.ps1 silently from the same folder as this .vbs file.
' =============================================================================
Option Explicit

Dim objShell, objFSO
Dim scriptDir, ps1Path, logPath, psCommand

Set objShell = CreateObject("WScript.Shell")
Set objFSO   = CreateObject("Scripting.FileSystemObject")

scriptDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
ps1Path   = scriptDir & "\preflight.ps1"
logPath   = scriptDir & "\launcher.log"

' ---- simple log helper ----
Sub WriteLog(msg)
    On Error Resume Next
    Dim f
    Set f = objFSO.OpenTextFile(logPath, 8, True)
    If Err.Number = 0 Then
        f.WriteLine "[" & Now() & "] " & msg
        f.Close
    End If
    On Error GoTo 0
End Sub

WriteLog "=== WTLC Preflight Launcher v5.4 starting ==="

' ---- verify script exists ----
If Not objFSO.FileExists(ps1Path) Then
    WriteLog "ERROR: preflight.ps1 not found at: " & ps1Path
    MsgBox "Preflight script not found!" & vbCrLf & vbCrLf & _
           "Expected: " & ps1Path & vbCrLf & vbCrLf & _
           "Make sure preflight.ps1 is in the same folder as this launcher.", _
           vbCritical, "WTLC Audio-Video Preflight"
    WScript.Quit 1
End If

WriteLog "Script found: " & ps1Path

' ---- build and run the command ----
' WindowStyle 0 = hidden, bWaitOnReturn False = fire-and-forget
psCommand = "powershell.exe -ExecutionPolicy Bypass -NonInteractive -NoProfile " & _
            "-WindowStyle Hidden -File """ & ps1Path & """"

WriteLog "Running: " & psCommand

On Error Resume Next
objShell.Run psCommand, 0, False

If Err.Number <> 0 Then
    WriteLog "ERROR launching PowerShell: " & Err.Description
    MsgBox "Could not start the preflight application." & vbCrLf & vbCrLf & _
           "Error: " & Err.Description & vbCrLf & vbCrLf & _
           "Try running preflight.ps1 directly as Administrator.", _
           vbCritical, "WTLC Audio-Video Preflight"
    WScript.Quit 1
End If
On Error GoTo 0

WriteLog "PowerShell launched successfully."
WriteLog "=== Launcher done ==="

Set objShell = Nothing
Set objFSO   = Nothing
WScript.Quit 0