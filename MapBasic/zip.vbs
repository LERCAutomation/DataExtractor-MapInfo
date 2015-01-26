'* DataExtractor is a MapInfo tool to extract biodiversity information
'* from SQL Server and MapInfo GIS layer for pre-defined spatial areas.
'*
'* Copyright © 2012-2013 Greenspace Information for Greater London (GiGL)
'* 
'* This file is part of the MapInfo tool 'DataExtractor'.
'* 
'* DataExtractor is free software: you can redistribute it and/or modify
'* it under the terms of the GNU General Public License as published by
'* the Free Software Foundation, either version 3 of the License, or
'* (at your option) any later version.
'* 
'* DataExtractor is distributed in the hope that it will be useful,
'* but WITHOUT ANY WARRANTY; without even the implied warranty of
'* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
'* GNU General Public License for more details.
'* 
'* You should have received a copy of the GNU General Public License
'* along with DataExtractor.  If not, see <http://www.gnu.org/licenses/>.
'*
'***************************************************************
'* zip.vbs v1.3
'*
'* Visual Basic script to compress source files into a
'* target zip file.
'*
'*
'* Created:         Andy Foy - December 2012
'* Last revised:    Andy Foy - February 2013
'***************************************************************

'---------------------------------
'Get command-line arguments.
'---------------------------------
Set objArgs = WScript.Arguments
InputFolder = objArgs(0)
ZipFile = objArgs(1)

'---------------------------------
'Default to 'COPY' if no argument provided
'---------------------------------
If objArgs.Count = 2 Then
    Action = "COPY"
Else
    Action = objArgs(2)
End If

'---------------------------------
'Set the source to the input folder items
'---------------------------------
set objShell = CreateObject("Shell.Application")
Set objFolder = objShell.NameSpace(InputFolder)

Set objItems = objFolder.Items()

If objItems Is Nothing Then
    WScript.Quit 1
End If

'---------------------------------
'Count the files in the input folder
'---------------------------------
SourceCount = objItems.Count

If SourceCount = 0 Then
    WScript.Quit 1
End If

'---------------------------------
'Create empty ZIP file.
'---------------------------------
CreateObject("Scripting.FileSystemObject").CreateTextFile(ZipFile, True).Write "PK" & Chr(5) & Chr(6) & String(18, vbNullChar)

'---------------------------------
'Copy all the objects in the source to the zip file
'---------------------------------
If UCase(Action) = "MOVE" OR UCase(Action) = "M" Then
    objShell.NameSpace(ZipFile).MoveHere(objItems)
Else
    objShell.NameSpace(ZipFile).CopyHere(objItems)
End If

'Wscript.Echo "Searching for Compress"

'---------------------------------
'Search for a Compressing dialog
'---------------------------------
Set oShl = CreateObject("WScript.Shell")
Do While oShl.AppActivate("Compressing...") = False

    If objShell.NameSpace(ZipFile).Items.Count = SourceCount Then
        'The zip file is done

        'Wscript.Echo "Zipping complete"

        Exit Do
    End If

    If l > 15 Then
        '---------------------------------
        '30 seconds has elapsed and no Compressing dialog
        'The zip may have completed already so exiting
        '---------------------------------

        'Wscript.Echo "Compress dialog not found"

        Exit Do
    End If

    WScript.Sleep 2000
    l = l + 1
Loop

'Wscript.Echo "Compress dialog found"

'---------------------------------
' Wait for compression to complete before exiting
'---------------------------------
Do While oShl.AppActivate("Compressing...") = True
    WScript.Sleep 1000
Loop

'Wscript.Echo "Compress dialog gone"

'---------------------------------
'Return an error code if the zipping did not complete
'---------------------------------
If objShell.NameSpace( ZipFile ).Items.Count < SourceCount Then
    'WScript.Echo "Compress dialog interupted"
    WScript.Quit 9
End If
