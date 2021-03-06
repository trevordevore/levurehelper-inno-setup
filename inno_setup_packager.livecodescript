script "Inno Setup Packager"
local sScriptsToCompile
local sWineCmd, sWinePathCmd

command processCopyFilesFile pBuildProfile, @xFiledata, pOutputFolder, pOutputFilename, pFileSettingsA
  local tConfigA, tFolders, tFiles, tFilename, tFlags, tInstallerFiles, tDirFiles

  _replaceVariables xFiledata, pBuildProfile

  put levureAppGet("inno setup") into tConfigA

  put _foldersInFolder(pOutputFolder & "/windows") into tFolders
  put _filesInFolder(pOutputFolder & "/windows") into tFiles

  /*
  Examples:
  Source: ".\windows\MyApp.exe"; DestDir: "{app}"; Flags: ignoreversion sign
  Source: ".\windows\levure.livecodescript"; DestDir: "{app}"; Flags: ignoreversion
  Source: ".\windows\helpers\*"; DestDir: "{app}\helpers"; Flags: ignoreversion recursesubdirs createallsubdirs
  */
  repeat for each line tFilename in tFolders
    if _filesInFolder(pOutputFolder & "/windows/" & tFilename) is empty and _foldersInFolder(pOutputFolder & "/windows/" & tFilename) is empty then
      put _q("Name: `{app}\" & tFilename & "`") & cr after tDirFiles
    else
      if tConfigA["sign executable files"] then
        _signFilesInFolder pOutputFolder & "/windows/", pOutputFolder & "/windows/" & tFilename, tInstallerFiles
      end if

      put _q("Source: `.\windows\" & tFilename & "\*`; DestDir: `{app}" & "\" & tFilename & "`;") after tInstallerFiles

      put _flagsForFilename(tConfigA, tFilename, true) into tFlags
      if tFlags is not empty then
        put space & tFlags after tInstallerFiles
      end if
      put cr after tInstallerFiles
    end if
  end repeat

  repeat for each line tFilename in tFiles
    put _q("Source: `.\windows\" & tFilename & "`; DestDir: `{app}`;") after tInstallerFiles

    put _flagsForFilename(tConfigA, pOutputFolder & "/windows/" & tFilename, false) into tFlags
    if tFlags is not empty then
      put space & tFlags after tInstallerFiles
    end if
    put cr after tInstallerFiles
  end repeat

  delete the last char of tInstallerFiles
  delete the last char of tDirFiles

  replace "[[FilesAndFoldersToInstall]]" with tInstallerFiles in xFiledata
  replace "[[DirectoriesToCreate]]" with tDirFiles in xFiledata

  if pFileSettingsA["compile"] is not false then
    put pOutputFolder & "/" & pOutputFilename into line (the number of lines of sScriptsToCompile + 1) of sScriptsToCompile
  end if
end processCopyFilesFile


/**
Summary: Goes through a folder looking for files that need to be signed.

Parameters:
pRootFolder: The root folder where installer files are located.
pFolder: The folder to process.
xOutput: Fill in with Inno Setup syntax for signing files.

Description:
Signs `.exe` and `.dll` files.

Returns: nothing
*/
private command _signFilesInFolder pRootFolder, pFolder, @xOutput
  local tSourceFilesFolderName, tFilename, tSrc, tDestDir

  set the itemDelimiter to "/"
  put the last item of pRootFolder into tSourceFilesFolderName

  repeat for each line tFilename in _filesInFolder(pFolder)
    if tFilename ends with ".exe" or tFilename ends with ".dll" or tFilename then
      # Fix permissions. LiveCode standalone builder sets permissions to 555 and user can't sign file.
      _setFilePermissions pFolder & "/" & tFilename, "execute", "read", "read"

      put pFolder & "/" & tFilename into tSrc
      replace pRootFolder with empty in tSrc
      put tSrc into tDestDir
      delete the last item of tDestDir # Target the folder, not the file name

      replace "/" with "\" in tSrc
      replace "/" with "\" in tDestDir

      if tDestDir is not empty then put "\" before tDestDir

      put _q("Source: `.\" & tSourceFilesFolderName & "\" & tSrc & "`; DestDir: `{app}" & tDestDir & "`; Flags: sign") & cr after xOutput
    end if
  end repeat

  repeat for each line tFilename in _foldersInFolder(pFolder)
    _signFilesInFolder pRootFolder, pFolder & "/" & tFilename, xOutput
  end repeat
end _signFilesInFolder


private function _filesInFolder pFolder
  local tFiles

  put files(pFolder) into tFiles
  filter tFiles without ".*"
  return tFiles
end _filesInFolder


private function _foldersInFolder pFolder
  local tFolders

  put folders(pFolder) into tFolders
  filter tFolders without ".*"
  filter tFolders without "..*"
  return tFolders
end _foldersInFolder


command packagingComplete pBuildProfile, pOutputFolder
  local tScriptsToCompile

  put sScriptsToCompile into tScriptsToCompile
  put empty into sScriptsToCompile

  if the platform is "win32" or _isWineInstalled() then
    local tSettingsA, tCompilerPath

    put levureAppGet("inno setup") into tSettingsA

    if the platform is "win32" then
      put tSettingsA["windows compiler"] into tCompilerPath
    else
      put tSettingsA["wine compiler"] into tCompilerPath
    end if

    if tCompilerPath is empty then
      put tSettingsA["compiler"] into tCompilerPath
    end if

    if tCompilerPath is empty then
      return empty
    end if

    if there is not a file tCompilerPath then
      put _findInnoCompilerPath(tSettingsA["compiler"]) into tCompilerPath
    end if

    if tCompilerPath is empty then
      return empty
    end if

    local tFlags
    if tCompilerPath ends with "Compil32.exe" then
      put "/cc" into tFlags
    end if

    local tCmd, tResult, tReturnVal

    repeat for each line tScript in tScriptsToCompile
      # compil32 /cc "c:\isetup\samples\my script.iss"
      if the platform is "win32" then
        replace "/" with "\" in tScript
        put format("\"%s\" %s \"%s\"", tCompilerPath, tFlags, tScript) into tCmd
        put shell(tCmd) into tResult
        put the result into tReturnVal
      else
        local tWineFilepath
        put _winePath(tScript) into tWineFilepath

        if tWineFilepath is not empty then
          put format("\"%s\" \"%s\" %s \"%s\"", sWineCmd, tCompilerPath, tFlags, tWineFilepath) into tCmd
          put shell(tCmd) into tResult
          put the result into tReturnVal
        end if
      end if

      if tReturnVal is 1 then
        put "inno setup result:" && tResult & cr & "for command:" && tCmd
        answer error param(0) && "invalid parameters passed to inno setup command line tool"
        exit repeat
      else if tReturnVal is not empty then
        put "inno setup result:" && tResult & cr & "for command:" && tCmd
        answer error param(0) && "inno setup compile failed" && tReturnVal
        exit repeat
      end if
    end repeat
  end if
end packagingComplete


private function _isWineInstalled
  if the platform is not "macos" then return false

  local tResult, tReturnVal

  put "wine" into sWineCmd
  put shell(sWineCmd && "--version 2> /dev/null") into tResult
  put the result into tReturnVal

  if tReturnVal is not empty then
    put "/usr/local/bin/wine" into sWineCmd
    put shell(sWineCmd && "--version 2> /dev/null") into tResult
    put the result into tReturnVal
  end if

  if tReturnVal is not empty then
    put empty into sWineCmd
    return false
  else
    set the itemDelimiter to "/"
    put sWineCmd into sWinePathCmd
    put "winepath" into the last item of sWinePathCmd
    return true
  end if
end _isWineInstalled

private function _findInnoCompilerPath pCompiler
  local tPath
  local tSep
  if the platform is "win32" then
    put word 1 to -1 of line 1 of shell("echo %PROGRAMFILES(x86)%") into tPath
    put "\" into tSep
  else
    put word 1 to -1 of line 1 of shell(sWineCmd && "cmd /c 'echo %PROGRAMFILES%' 2> /dev/null") into tPath
    put "/" into tSep
    put _winePath(tPath) into tPath
  end if

  if there is a file (tPath & tSep & pCompiler) then
    return tPath & tSep & pCompiler
  end if

  local tFolders
  put folders(tPath) into tFolders
  filter tFolders with "Inno Setup*"
  if tFolders is empty then
    return empty
  end if

  sort lines of tFolders descending by the last word of each
  put tSep & line 1 of tFolders & tSep & pCompiler after tPath

  if there is a file tPath then
    return tPath
  else
    return empty
  end if
end _findInnoCompilerPath

private function _winePath pPath
  local tFlags
  if pPath contains "/" then
    put "-w" into tFlags
  else
    put "-u" into tFlags
  end if

  local tCmd
  put format("\"%s\" %s \"%s\" 2> /dev/null", sWinePathCmd, tFlags, pPath) into tCmd
  get shell(tCmd)
  if the result is empty then
    return word 1 to -1 of line 1 of it
  else
    return empty
  end if
end _winePath

private command _replaceVariables @xFileData, pBuildProfile
  local tVersion, tConfigA

  put levureAppGet("version") into tVersion
  set the itemDelimiter to "."

  replace textEncode("[[NAME]]", "utf8") with levureAppGet("name") in xFileData
  replace textEncode("[[VERSION]]", "utf8") with tVersion in xFileData
  replace textEncode("[[MAJOR_VERSION]]", "utf8") with item 1 of tVersion in xFileData
  replace textEncode("[[APP_VERSION]]", "utf8") with item 1 to 2 of tVersion in xFileData
  replace textEncode("[[BUILD]]", "utf8") with levureAppGet("build") in xFileData
  replace textEncode("[[BUILD_PROFILE]]", "utf8") with tolower(pBuildProfile) in xFileData

  local tInstallerName

  put levureAppGet("build profiles") into tConfigA

  put tConfigA[pBuildProfile]["installer name"]["windows"] into tInstallerName
  if tInstallerName is empty then
    put tConfigA["all profiles"]["installer name"]["windows"] into tInstallerName
  end if
  if tInstallerName is empty then
    put tConfigA[pBuildProfile]["installer name"]["all platforms"] into tInstallerName
  end if
  if tInstallerName is empty then
    put tConfigA["all profiles"]["installer name"]["all platforms"] into tInstallerName
  end if

  replace textEncode("[[INSTALLER_NAME]]", "utf8") with tInstallerName in xFileData
end _replaceVariables


private function _flagsForFilename pConfigA, pFilename, pIsFolder
  local tFlags

  if pIsFolder then
    if pConfigA["folder flags"] is not empty then
      put "Flags: " & pConfigA["folder flags"] into tFlags
    end if
  else
    if pConfigA["file flags"] is not empty then
      put "Flags: " & pConfigA["file flags"] into tFlags
    end if

    if (pFilename ends with ".exe" or pFilename ends with ".dll") and pConfigA["sign executable files"] then
      # Fix permissions. LiveCode standalone builder sets permissions to 555 and user can't sign file.
      _setFilePermissions pFilename, "execute", "read", "read"

      if tFlags is empty then
        put "Flags:" after tFlags
      end if

      put " sign" after tFlags
    end if
  end if

  return tFlags
end _flagsForFilename


private function _q pStr
  replace "`" with quote in pStr
  return pStr
end _q


private command _setFilePermissions pFile, pOwner, pGroup, pAll
  local tError, tResult

  put _escapeForShell(pFile) into pFile

  switch the platform
    case "Win32"
      /*
      Displays or changes file attributes.
      ATTRIB [+R | -R] [+A | -A] [+S | -S] [+H | -H] [[drive:][path]filename]  [/S] [/D]

      + Sets an attribute.
      - Clears an attribute.
      R Read-only file attribute.
      A Archive file attribute.
      S system file attribute.
      H Hidden file attribute.
      /S Processes files in all directories in the specified path.
      /D Processes folders as well
      */

      switch pOwner
        case "read"
          put "+r" into pOwner
          break
        case "write"
          put "-r" into pOwner
          break
      end switch
      put shell (format ("attrib %s %s", pOwner, pFile) ) into tResult
      break

    case "MacOS"
      put _executableBitFromType(pOwner) into pOwner
      put _executableBitFromType(pGroup) into pGroup
      put _executableBitFromType(pAll) into pAll
      put shell(format("chmod %u%u%u %s ", pOwner, pGroup, pAll, pFile)) into tResult
      break
  end SWITCH

  if the result is not empty then
    put line 1 of tResult into tError
  end if

  return tError
end _setFilePermissions


private function _executableBitFromType pType
  switch pType
    case "execute"
      put 7 into pType
      break
    case "write"
      put 6 into pType
      break
    case "read"
      put 5 into pType
      break
    default
      put 0 into pType
  end switch
  return pType
end _executableBitFromType


private function _escapeForShell pStr
  local tChar, tSpecialChars

  if the platform is "win32" then
    replace "/" with "\" in pStr
    put quote & pStr & quote into pStr
  else
    put "\" & space & quote & "'`<>!;()[]?#$^&*=|" into tSpecialChars
    repeat for each char tChar in tSpecialChars
      replace tChar with ("\" & tChar) in pStr
    end REPEAT
  end if

  return pStr
end _escapeForShell
