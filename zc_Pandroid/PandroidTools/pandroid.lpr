{*******************************************************************
* Zeljko Cvijanovic www.zeljus.com (cvzeljko@gmail.com)  &         *
*              Miran Horjak usbdoo@gmail.com                       *
*                                                                  *
* Pandroid is released under Mozilla Public License 2.0 (MPL-2.0)  *
* https://tldrlegal.com/license/mozilla-public-license-2.0-(mpl-2) *
*                           2020                                   *
********************************************************************}
program pandroid;

{$apptype console}
//{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ELSE}
   ShellApi,
   FileUtil,
  {$ENDIF}
  Classes, IniFiles, XMLCfg, SysUtils, process, LazFileUtils;

Var
  gProjectDir,
  gJavaPackageName,
  gAndroidSDKDir,
  gTarget,
  gBuildTools,
  gAppName,
  gActivityName,
  gSendApk,
  gPandroid,
  gJavaHome: String;

procedure LoadIniFile;
var
   IniFile : TIniFile;
begin
   IniFile := TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini'));
   try
     gAndroidSDKDir     := IniFile.ReadString('pandroid', 'AndroidSDKDir', '/usr/local/pandroid/sdk');
     gTarget            := IniFile.ReadString('pandroid', 'Target', 'android-15');
     gBuildTools        := IniFile.ReadString('pandroid', 'BuildTools', '23.0.3');
     gSendApk           := IniFile.ReadString('pandroid', 'SendApk', '1');
     gJavaHome          := IniFile.ReadString('pandroid', 'JAVA_HOME', 'E:\Zeljus\Java\');
     gActivityName  := 'MainActivity';
   finally
     IniFile.Free;
   end;
end;

procedure SaveIniFile;
var
   IniFile : TIniFile;
begin
  IniFile := TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini'));
  try
     IniFile.WriteString('pandroid', 'AndroidSDKDir',   gAndroidSDKDir);
     IniFile.WriteString('pandroid', 'Target',          gTarget);
     IniFile.WriteString('pandroid', 'BuildTools',      gBuildTools);
     IniFile.WriteString('pandroid', 'SendApk',         gSendApk);
     IniFile.WriteString('pandroid', 'JAVA_HOME',       gJavaHome);
  finally
    IniFile.Free;
  end;
end;


function Replace(S, Old, New: String): String;
var i: integer;
begin
  Result := '';
  for i:=1 to Length(S) do begin
     if S[i]=Old then Result := Result + New
     else Result := Result + S[i];
  end;
end;

function StringNameReplace(S: String): String;
begin
 S :=  StringReplace(S, '#ProjectDir#',      gProjectDir,      [rfReplaceAll]);
 S :=  StringReplace(S, '#JavaPackageName#', gJavaPackageName, [rfReplaceAll]);
 S :=  StringReplace(S, '#AndroidSDKDir#',   gAndroidSDKDir,   [rfReplaceAll]);
 S :=  StringReplace(S, '#Target#',          gTarget,          [rfReplaceAll]);
 S :=  StringReplace(S, '#BuildTools#',      gBuildTools,      [rfReplaceAll]);
 S :=  StringReplace(S, '#AppName#',         gAppName,         [rfReplaceAll]);
 S :=  StringReplace(S, '#ActivityName#',    gActivityName,    [rfReplaceAll]);
 S :=  StringReplace(S, '#PANDROID#',        gPandroid,        [rfReplaceAll]);
 S :=  StringReplace(S, '#DatumVreme#',      DateTimeToStr(now),        [rfReplaceAll]);
 Result := S;
end;

procedure ReadLpiFile;
var
  XMLConfig: TXMLConfig;
begin
  XMLConfig := TXMLConfig.Create(nil);
  XMLConfig.Filename := gProjectDir + PathDelim + gAppName+'.lpi';
  try
    gJavaPackageName := XMLConfig.GetValue('CompilerOptions/BuildMacros/Item1/Values/Item1/Value', '');
  finally
    XMLConfig.Free;
  end;
end;

procedure BuildRJavaFiles(tAppName, tJavaPackageName, tRJava, tRJavaPAs: string);

var
  lFile: TStringList;
  InFile: TStringList;
  i, j: integer;

  InClass : Boolean;
  InConst : Boolean;
  InStr: String;
begin
  writeln('BuildRJavaFiles('+tAppName+', '+tJavaPackageName+', '+tRJava+', '+tRJavaPAs);
  lFile := TStringList.Create;
  InFile := TStringList.Create;
  try
    lFile.Add('// AUTO-GENERATED FILE. DO NOT MODIFY.');
    lFile.Add('');
    lFile.Add('// This class was automatically generated by the ' + tAppName + ' tool');
    lFile.Add('// from R.java. It should not be modified by hand.');
    lFile.Add('');
    lFile.Add('unit Rjava;');
    lFile.Add('');
    lFile.Add('{$mode objfpc}{$H+}');
    lFile.Add('{$modeswitch unicodestrings}');
    lFile.Add('{$namespace ' + tJavaPackageName + '}');
    lFile.Add('');
    lFile.Add('interface');
    lFile.Add('');
    lFile.Add('type');
    lFile.Add('  R = class');
    lFile.Add('  public');
    lFile.Add('    type');

    InFile.LoadFromFile(tRjava); //lista files *.pas

    j:= 0;
    repeat
      InStr := Trim(InFile.Strings[j]);
      j := j + 1;
    until Copy(InStr, 1, 21) = 'public final class R ';
   InClass := False;
   InConst := False;

    for i:=j to InFile.Count - 1 do begin
      InStr := Trim(InFile.Strings[i]);

      if Copy(InStr, 1, 26) = 'public static final class ' then begin
        InStr := Copy(InStr, 27, MaxInt);
        if Pos('{', InStr) > 0 then
          InStr := Copy(InStr, 1, Pos('{', InStr)-1);
        InStr := Trim(InStr);

        if InStr = 'string' then InStr := 'string_';
        if InStr = 'array' then  InStr := 'array_';

        lFile.Add('      '+InStr+' = class');
        InClass := True;
        end
      else if InClass and (Copy(InStr, 1, 24) = 'public static final int ') then begin
        if not InConst then begin
            lFile.Add('      public');
            lFile.Add('        const');
            InConst := True;
          end;
        InStr := Copy(InStr, 25, MaxInt);
        InStr := StringReplace(InStr, '=0x', ' = $', []);
        lFile.Add('          '+InStr);
        end
      else if InClass and (InStr = '}') then begin
         lFile.Add('      end;');
         lFile.Add(' ');
         InClass := False;
         InConst := False;
        end;
   end;

   lFile.Add('  end;');
   lFile.Add('');
   lFile.Add('implementation');
   lFile.Add('');
   lFile.Add('end.');

    DeleteFile(gProjectDir + PathDelim + 'Rjava.pas');
   lFile.SaveToFile(tRJavaPas);

  finally
    lFile.Free;
    InFile.Free;
  end;
end;


function ShellRun(curdir: String; exename: String; commands:array of String; var outputstring:string):boolean;
begin
  {$IFDEF Linux}
   Result := RunCommandIndir(curdir, exename, commands, outputstring, [poWaitOnExit,poStderrToOutPut,poNoConsole]);
  {$ELSE}
  // Result := RunCommandIndir(curdir, exename, commands, outputstring, [poWaitOnExit,poStderrToOutPut,poNoConsole]);


  {$ENDIF}
  Sleep(300);
end;

//-compiler

procedure Build_Before(APackgDir: String; AProjFile: String);
var
  Str: String;
  lFile: TStringList;
  i: integer;
  {$IFDEF Linux}
  Message: String;
  arguments: array of string;
  executable: string;
  {$ELSE}
  AProcess: TProcess;
  {$ENDIF}
  
begin
   LoadIniFile;
   gAppName := ExtractFileNameOnly(AProjFile);
   gProjectDir := ExtractFileDir(AProjFile);
   gPandroid := Copy(APackgDir, 1, Length(APackgDir)- 1);
   ReadLpiFile;  //citanje xml lpi podataka := ;
   Writeln('--- Build_Before('+APackgDir+'  '+ AProjFile);

   lFile:= TStringList.Create;
   try
       //project.properties
       lFile.Add('# Project target.');
       lFile.Add('target='+ gTarget);
       lFile.Add('# SDK directory');
       {$ifdef linux}
       lFile.Add('sdk.dir='+ gAndroidSDKDir);
       {$else}
        lFile.Add('sdk.dir=' + Replace(gAndroidSDKDir, '\', '\\'));
       {$endif}
       lFile.SaveToFile(gProjectDir + PathDelim + 'android' + Pathdelim +'project.properties');

      //ant.properties
      lFile.Clear;
       lFile.LoadFromFile(APackgDir + PathDelim + 'template' + PathDelim  + 'ant.properties');
       for i:=0 to lFile.Count - 1 do begin
         lFile.Strings[i] := StringNameReplace(lFile.Strings[i]);
         {$IFDEF Windows}
         if pos('key.store', lFile.Strings[i]) <> 0 then begin
         lFile.Strings[i] := StringReplace(lFile.Strings[i], '\',   '\\' ,   [rfReplaceAll]);
         lFile.Strings[i] := StringReplace(lFile.Strings[i], '/',   '\\' ,   [rfReplaceAll]);
         end else
         lFile.Strings[i] := StringReplace(lFile.Strings[i], '/',   '\\' ,   [rfReplaceAll]);
         {$ENDIF}
       end;
       lFile.SaveToFile(gProjectDir + PathDelim + 'android'+ PathDelim + 'ant.properties');

       {$IFDEF LINUX}
           //Delete apk
           SetLength(arguments, 1);
           executable := 'rm';
           arguments[0] := gProjectDir+ PathDelim + gAppName+'.apk';
           if ShellRun(gProjectDir + PathDelim + 'android' + PathDelim, executable, arguments, Message ) then
                 Writeln('=================OK.... rm apk '+LineEnding + Message+LineEnding)
           else  begin Writeln('=================ERROR .... rm apk '+LineEnding + Message+LineEnding); {Abort;} end;  
           
           //ant clean
           SetLength(arguments, 1);
           executable := 'ant';
           arguments[0] := 'clean';
           if ShellRun(gProjectDir + PathDelim + 'android' + PathDelim, executable, arguments, Message ) then
                 Writeln('=================OK.... ant clean '+LineEnding + Message+LineEnding)
           else  begin Writeln('=================ERROR .... ant clean '+LineEnding + Message+LineEnding); Abort; end;

           //create directory
           SetLength(arguments, 2);
           executable := 'mkdir';
           arguments[0] := '-p';
           arguments[1] := gProjectDir+PathDelim+'android'+PathDelim+'bin';
           if ShellRun(gProjectDir + PathDelim + 'android' + PathDelim, executable, arguments, Message) then
                 Writeln('=================OK.... mkdir android/bin' +LineEnding+ Message+LineEnding)
           else begin Writeln('=================ERROR .... mkdir andorid/bin' +LineEnding+ Message+LineEnding); Abort; end;

           SetLength(arguments, 2);
           executable := 'mkdir';
           arguments[0] := '-p';
           arguments[1] := gProjectDir+PathDelim+'android'+PathDelim+'bin'+PathDelim+'classes';
           if ShellRun(gProjectDir + PathDelim + 'android' + PathDelim, executable, arguments, Message) then
                 Writeln('=================OK.... mkdir android/bin/classes' +LineEnding+ Message+LineEnding)
           else begin Writeln('=================ERROR .... mkdir andorid/bin/classes' +LineEnding+ Message+LineEnding); Abort; end;

           SetLength(arguments, 2);
           executable := 'mkdir';
           arguments[0] := '-p';
           arguments[1] := gProjectDir+PathDelim+'android'+PathDelim+'gen';
           if ShellRun(gProjectDir + PathDelim + 'android' + PathDelim, executable, arguments, Message) then
                 Writeln('=================OK.... mkdir android/gen' +LineEnding+ Message+LineEnding)
           else  begin Writeln('=================ERROR .... mkdir andorid/gen' +LineEnding+ Message+LineEnding); Abort; end;


           //create gen/  R.java
           SetLength(arguments, 15);
           executable :=  'aapt';
           arguments[0] := 'package';
           arguments[1] := '-m';
           arguments[2] := '-J';
           arguments[3] := gProjectDir+PathDelim+'android'+PathDelim+'gen';
           arguments[4] := '-M';
           arguments[5] := gProjectDir+PathDelim+'android'+PathDelim+'AndroidManifest.xml';
           arguments[6] := '-S';
           arguments[7] := gProjectDir+PathDelim+'android'+PathDelim+'res';
           arguments[8] := '-I';
           arguments[9] := gAndroidSDKDir+PathDelim+'platforms'+PathDelim+ gTarget+PathDelim+'android.jar';
           arguments[10] := '-S';
           arguments[11] := gProjectDir+PathDelim+'android'+PathDelim+'res';
           arguments[12] := '-m';
           arguments[13] := '-J';
           arguments[14] := gProjectDir+PathDelim+'android'+PathDelim+'gen';

           if ShellRun(gAndroidSDKDir+PathDelim+'build-tools'+PathDelim+gBuildTools, executable, arguments, Message) then
                 Writeln('=================OK.... aapt' +LineEnding+ Message+LineEnding)
           else begin Writeln('=================ERROR .... aapt' +LineEnding+ Message+LineEnding); Abort; end;
       {$ELSE}
          lFile.Clear;
          lFile.Add('cd '+ gProjectDir+'\android' );
          lFile.Add('del '+ gProjectDir+ PathDelim + gAppName+'.apk');
          lFile.Add('rd bin /s /q');
          lFile.Add('rd gen /s /q');
          lFile.Add('mkdir bin');
          lFile.Add('mkdir bin\classes');
          lFile.Add('mkdir gen');
          lFile.Add('');
          lFile.Add(gAndroidSDKDir+'\build-tools\'+gBuildTools+'\aapt.exe '+
                   'package -m -J '+
                   gProjectDir+'\android\gen -M '+
                   gProjectDir+'\android\AndroidManifest.xml -S '+
                   gProjectDir+'\android\res -I '+
                   gAndroidSDKDir+'\platforms\'+gTarget+'\android.jar -S '+
                   gProjectDir+'\android\res -m -J '+
                   gProjectDir+'\android\gen ');

          lFile.SaveToFile(gProjectDir+'\android\BuildBefore.bat');
          AProcess:= TProcess.Create(nil);
          try
            AProcess.CommandLine:= gProjectDir+'\android\BuildBefore.bat > '+gProjectDir+'\android\OutBefore.txt';
            AProcess.Options:=[poUsePipes, poWaitOnExit];
            AProcess.Execute;
            if FileExistsUTF8(gProjectDir+'\android\OutBefore.txt') then begin
              lFile.LoadFromFile(gProjectDir+'\android\OutBefore.txt');
              Writeln(lFile.Text);
            end;

          finally
            AProcess.Free;
          end;
       {$ENDIF}


        //create R.java to RJava.pas
        Str := StringReplace(gJavaPackageName, '.', PathDelim, [rfReplaceAll]);
        ForceDirectories(gProjectDir + PathDelim+ 'android' + PathDelim + 'gen' + PathDelim + Str);
        BuildRJavaFiles(gAppName,
                  gJavaPackageName,
                  gProjectDir + PathDelim + 'android' + PathDelim+'gen'+PathDelim+ Str+PathDelim+'R.java',
                  gProjectDir+PathDelim +'Rjava.pas');

   finally
     lFile.Free;
   end;
end;


procedure Build_After(APackgDir: String; AProjFile: String);
var
 {$IFDEF Linux}
  Message: String;
  arguments: array of string;
  executable: string;
  {$ELSE}
   lFile: TStringList;
   AProcess: TProcess;
  {$ENDIF}
begin
    LoadIniFile;
    gAppName := ExtractFileNameOnly(AProjFile);
    gProjectDir := ExtractFileDir(AProjFile);
    gPandroid := Copy(APackgDir, 1, Length(APackgDir)- 1);
    ReadLpiFile;  //citanje xml lpi podataka := ;

    Writeln('START Compile apk... Build_After('+APackgDir+' '+AProjFile );

    try
      {$IFDEF LINUX}
      //ant release
      SetLength(arguments, 2);
      executable := 'ant';
      arguments[0] := '-verbose';
      arguments[1] := 'release';
      if ShellRun(gProjectDir + PathDelim + 'android' + PathDelim, executable, arguments, Message) then
         Writeln('========================OK.... ant release' + LineEnding+ Message+ LineEnding)
      else  Writeln('=================ERROR .... ant release' + LineEnding + Message+ LineEnding);

      //test jarsigner
      SetLength(arguments, 4);
      executable := 'jarsigner';
      arguments[0] := '-verify';
      arguments[1] := '-verbose';
      arguments[2] := '-certs';
      arguments[3] := gProjectDir+PathDelim+gAppName+'.apk';
      if ShellRun(gProjectDir + PathDelim + 'android' + PathDelim, executable, arguments, Message) then
         Writeln('========================OK.... jarsigner verify certs ' + LineEnding+ Message+ LineEnding)
      else begin Writeln('=================ERROR .... jarsigner verify certs ' + LineEnding + Message+ LineEnding); Abort; end;

     {$ELSE}
        lFile:= TStringList.Create;
        try
          lFile.Add('cd '+gProjectDir+'\android\');
          lFile.Add('set JAVA_HOME='+gJavaHome+'\&lt;jdkdir&gt;');
          lFile.Add('ant -verbose release');
          lFile.Add('jarsigner -verify -verbose -certs '+gProjectDir+PathDelim+gAppName+'.apk');

          lFile.SaveToFile(gProjectDir+'\android\BuildApk.bat');

          AProcess:= TProcess.Create(nil);
          try
            AProcess.CommandLine:= gProjectDir+'\android\BuildApk.bat > '+gProjectDir+'\android\OutAfter.txt';
            AProcess.Options:=[poUsePipes, poWaitOnExit];
            AProcess.Execute;
            if FileExistsUTF8(gProjectDir+'\android\OutAfter.txt') then begin
              lFile.LoadFromFile(gProjectDir+'\android\OutAfter.txt');
              Writeln(lFile.Text);
            end;
          finally
            AProcess.Free;
          end;

        finally
          lFile.Free;
        end;

     {$ENDIF}


        Writeln('****************************************************************'+#10);
        Writeln('Create android application: '+ gProjectDir + PathDelim +  gAppName+'.apk'+#10);
        Writeln('****************************************************************'+#10);


        if gSendApk = '1' then begin  //send to usb port (PDA)   adb
          {$IFDEF LINUX}
           //uninstall application to android device
            SetLength(arguments, 5);
            executable := 'adb';
            arguments[0] := 'shell';
            arguments[1] := 'pm';
            arguments[2] := 'uninstall';
            arguments[3] := '-k';
            arguments[4] := gJavaPackageName;
            if ShellRun(gProjectDir + PathDelim, executable, arguments, Message) then
               Writeln('========================OK.... adb shell pm uninstall -k '+ gJavaPackageName + LineEnding+ Message+ LineEnding)
            else begin Writeln('=================ERROR .... adb shell pm uninstall -k '+ gJavaPackageName  + LineEnding + Message+ LineEnding); Abort; end;

            //install application to android device
            SetLength(arguments, 2);
            executable := 'adb';
            arguments[0] := 'install';
            arguments[1] := gProjectDir+ PathDelim + gAppName+'.apk';
            if ShellRun(gProjectDir + PathDelim, executable, arguments, Message) then
               Writeln('========================OK.... adb install '+ gProjectDir+ PathDelim + gAppName+'.apk' + LineEnding+ Message+ LineEnding)
            else begin Writeln('=================ERROR .... adb install'+ gProjectDir+ PathDelim + gAppName+'.apk' + LineEnding + Message+ LineEnding); Abort; end;

           //start application to android device
           SetLength(arguments, 5);
           executable := 'adb';
           arguments[0] := 'shell';
           arguments[1] := 'am';
           arguments[2] := 'start';
           arguments[3] := '-n';
           arguments[4] :=  gJavaPackageName +PathDelim+ gJavaPackageName+'.MainActivity';
           if ShellRun(gProjectDir + PathDelim, executable, arguments, Message) then
              Writeln('========================OK.... START '+ gJavaPackageName +PathDelim+ gJavaPackageName+'.MainActivity' + LineEnding+ Message+ LineEnding)
           else begin Writeln('=================ERROR .... START '+ gJavaPackageName +PathDelim+ gJavaPackageName+'.MainActivity' + LineEnding + Message+ LineEnding); Abort; end;
           {$ELSE}
            Writeln('======================== START ADB uninstall, install, start ');

            lFile:= TStringList.Create;
            try
              lFile.Add('cd '+gProjectDir);
              lFile.Add('adb shell pm uninstall -k '+gJavaPackageName);
              lFile.Add('adb install '+gProjectDir+ PathDelim + gAppName+'.apk');
              lFile.Add('adb shell am start -n '+gJavaPackageName +PathDelim+ gJavaPackageName+'.MainActivity');

              lFile.SaveToFile(gProjectDir+'\android\BuildAdb.bat');

              AProcess:= TProcess.Create(nil);
              try
                AProcess.CommandLine:= gProjectDir+'\android\BuildAdb.bat > '+gProjectDir+'\android\OutAdb.txt';
                AProcess.Options:=[poWaitOnExit, poUsePipes];
                AProcess.Execute;

                if FileExistsUTF8(gProjectDir+'\android\OutAdb.txt') then begin
                  lFile.LoadFromFile(gProjectDir+'\android\OutAdb.txt');
                  Writeln(lFile.Text);
                end;
              finally
                AProcess.Free;
              end;

            finally
              lFile.Free;
            end;
           {$ENDIF}
         end;

    finally
    end;
end;


begin
  if  (ParamStr(1) = 'R') then
    Build_Before(ParamStr(2), ParamStr(3) )
  else if (ParamStr(1) = 'B') then
     Build_After(ParamStr(2), ParamStr(3) );

end.

