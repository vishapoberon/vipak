MODULE vpkJsonDepRetriever;
IMPORT Strings, Out,
       List, StringList, strUtils, Json, vpkStorage, vpkSettings, vpkdepTree;

CONST
  ErrmessSize = 4096;

VAR
  currentLocalProjectFile: ARRAY 256 OF CHAR;

PROCEDURE ToLower(VAR stringVar: ARRAY OF CHAR);
VAR
  i: INTEGER;
BEGIN
  i := 0;
  WHILE stringVar[i] # 0X DO
    IF (stringVar[i] >= "A") & (stringVar[i] <= "Z") THEN
      stringVar[i] := CHR(ORD(stringVar[i]) + 20H);
    END;
    INC(i);
  END;
END ToLower;

PROCEDURE getBuildInfo*(VAR d: vpkdepTree.Tdep; VAR k, v: StringList.TStringList): BOOLEAN;
VAR
  jsonstr, errstr: strUtils.pstring;
  tree, buildValue, command, file: Json.Value;
  rootObj, buildStep: Json.Obj;
  buildArray: Json.Arr;
  cm, fl, bl, cmLower, flLower: Json.jString;
  b: BOOLEAN;
BEGIN
  k := NIL; v := NIL;
  b := FALSE;
  jsonstr := NIL;
  vpkStorage.json2pstring(d.name^, jsonstr);
  IF jsonstr # NIL THEN
    NEW(errstr, ErrmessSize);
    b := Json.Parse(tree, jsonstr^, errstr^);
    IF b THEN
      IF tree IS Json.Obj THEN
        rootObj := tree(Json.Obj);
        NEW(bl, Strings.Length(vpkSettings.bldType) + 1); (* +1 for 0X *)
        COPY(vpkSettings.bldType, bl^);
        IF Json.ObjSelect(buildValue, rootObj, bl) THEN
          IF buildValue IS Json.Arr THEN
            buildArray := buildValue(Json.Arr);
            WHILE buildArray # NIL DO
              buildStep := buildArray.value(Json.Obj);
              NEW(cm, Strings.Length(vpkSettings.bldCommand) + 1); (* +1 for 0X *)
              NEW(fl, Strings.Length(vpkSettings.bldFile) + 1);    (* +1 for 0X *)
              COPY(vpkSettings.bldCommand, cm^);
              COPY(vpkSettings.bldFile, fl^);
              IF (d^.Type = vpkSettings.https) OR (d^.Type = vpkSettings.http) THEN
                (* Handle HTTPS build steps *)
                IF Json.ObjSelect(command, buildStep, cm) & Json.ObjSelect(file, buildStep, fl) THEN
                  IF (command IS Json.Str) & (file IS Json.Str) THEN
                    IF k = NIL THEN k := StringList.Create() END;
                    IF v = NIL THEN v := StringList.Create() END;
                    k.AppendString(k, command(Json.Str).str^);
                    v.AppendString(v, file(Json.Str).str^);
                  ELSE
                    Out.String("command and file must be strings"); Out.Ln;
                    HALT(5);
                  END;
                ELSE
                  Out.String("Failed to select 'command' or 'file' from build step"); Out.Ln;
                END;
              ELSIF d^.Type = vpkSettings.git THEN
                (* Handle Git build steps *)
                NEW(cmLower, Strings.Length(cm^) + 1);
                NEW(flLower, Strings.Length(fl^) + 1);
                COPY(cm^, cmLower^);
                COPY(fl^, flLower^);
                ToLower(cmLower^);
                ToLower(flLower^);
                IF Json.ObjSelect(command, buildStep, cmLower) & Json.ObjSelect(file, buildStep, flLower) THEN
                  IF (command IS Json.Str) & (file IS Json.Str) THEN
                    IF k = NIL THEN k := StringList.Create() END;
                    IF v = NIL THEN v := StringList.Create() END;
                    k.AppendString(k, command(Json.Str).str^);
                    v.AppendString(v, file(Json.Str).str^);
                  ELSE
                    Out.String("command and file must be strings"); Out.Ln;
                    HALT(5);
                  END;
                ELSE
                  Out.String("Failed to select 'command' or 'file' from build step"); Out.Ln;
                END;
              END;
              buildArray := buildArray.next;
            END;
          ELSE
            Out.String("Build section is not an array."); Out.Ln;
          END;
        ELSE
          Out.String("Build section not found."); Out.Ln;
        END;
      ELSE
        Out.String("JSON root is not an object."); Out.Ln;
      END;
    ELSE
      Out.String("JSON parsing failed: "); Out.String(errstr^); Out.Ln;
    END;
  ELSE
    Out.String("No JSON string provided."); Out.Ln;
  END;
  RETURN b;
END getBuildInfo;

(*PROCEDURE fetchHttpsFiles(someObj: Json.Obj; VAR httpsRemote: vpkdepTree.RemoteHttps);*)
PROCEDURE fetchHttpsFiles(someObj: Json.Obj; VAR Remote: vpkdepTree.Remote);
VAR
  filesArray, fileObjValue: Json.Value;
  fileObj, authObj: Json.Obj;
  urlValue, authTypeValue, md5Value, authCredsValue, userValue, passwordValue: Json.Value;
  url, authType, authCr, user, password, md5: Json.jString;
  httpsFile: vpkdepTree.File;
BEGIN
  IF Remote IS vpkdepTree.RemoteHttp THEN
    IF Remote(vpkdepTree.RemoteHttp)^.Files = NIL THEN
      Remote(vpkdepTree.RemoteHttp)^.Files := List.Create();
    END
  ELSIF Remote IS vpkdepTree.RemoteHttps THEN
    IF Remote(vpkdepTree.RemoteHttps)^.Files = NIL THEN
      Remote(vpkdepTree.RemoteHttps)^.Files := List.Create();
    END

  ELSE
    Out.String("HTTP or HTTPS protocols expected, check package description"); Out.Ln;
    HALT(11);
  END;
  (*
  IF httpsRemote^.Files = NIL THEN
    httpsRemote^.Files := List.Create();
  END;
  *)
  WHILE someObj # NIL DO
    IF someObj.value IS Json.Arr THEN
      filesArray := someObj.value(Json.Arr);
      WHILE filesArray # NIL DO
        fileObjValue := filesArray(Json.Arr).value;
        IF fileObjValue IS Json.Obj THEN
          fileObj := fileObjValue(Json.Obj);
          NEW(httpsFile);
          httpsFile^.auth := FALSE; (* default *)
          (* extract url *)
          NEW(url, Strings.Length(vpkSettings.rmtFileURL) + 1);
          COPY(vpkSettings.rmtFileURL, url^);
          IF Json.ObjSelect(urlValue, fileObj, url) & (urlValue IS Json.Str) THEN
            COPY(urlValue(Json.Str).str^, httpsFile^.URI);
          END;
          (* extract authtype *)
          NEW(authType, Strings.Length(vpkSettings.rmtFileAuthType) + 1);
          COPY(vpkSettings.rmtFileAuthType, authType^);
          IF Json.ObjSelect(authTypeValue, fileObj, authType) & (authTypeValue IS Json.Str) THEN
            IF authTypeValue(Json.Str).str^ = vpkSettings.rmtFileAuthValBasic THEN
              httpsFile^.auth := TRUE;
              (* extract auth credentials *)
              NEW(authCr, Strings.Length(vpkSettings.rmtFileAuthCreds) + 1);
              COPY(vpkSettings.rmtFileAuthCreds, authCr^);
              IF Json.ObjSelect(authCredsValue, fileObj, authCr) & (authCredsValue IS Json.Obj) THEN
                authObj := authCredsValue(Json.Obj);
                NEW(user, Strings.Length(vpkSettings.rmtFileAuthUsr) + 1);
                COPY(vpkSettings.rmtFileAuthUsr, user^);
                IF Json.ObjSelect(userValue, authObj, user) & (userValue IS Json.Str) THEN
                  COPY(userValue(Json.Str).str^, httpsFile^.username);
                END;
                NEW(password, Strings.Length(vpkSettings.rmtFileAuthPwd) + 1);
                COPY(vpkSettings.rmtFileAuthPwd, password^);
                IF Json.ObjSelect(passwordValue, authObj, password) & (passwordValue IS Json.Str) THEN
                  COPY(passwordValue(Json.Str).str^, httpsFile^.password);
                END;
              END;
            ELSE
              httpsFile^.auth := FALSE;
            END;
          END;
          (* extract md5 *)
          NEW(md5, Strings.Length(vpkSettings.rmtFileMD5) + 1);
          COPY(vpkSettings.rmtFileMD5, md5^);
          IF Json.ObjSelect(md5Value, fileObj, md5) & (md5Value IS Json.Str) THEN
            COPY(md5Value(Json.Str).str^, httpsFile^.md5);
            Out.String("found md5 "); Out.String(httpsFile^.md5); Out.Ln;
          END;
          (*httpsRemote^.Files.Append(httpsRemote^.Files, httpsFile);*)
          IF Remote IS vpkdepTree.RemoteHttp THEN
            Remote(vpkdepTree.RemoteHttp)^.Files.Append(Remote(vpkdepTree.RemoteHttp)^.Files, httpsFile);
          ELSIF Remote IS vpkdepTree.RemoteHttps THEN
            Remote(vpkdepTree.RemoteHttps)^.Files.Append(Remote(vpkdepTree.RemoteHttps)^.Files, httpsFile);
          END;
        END;
        filesArray := filesArray(Json.Arr).next;
      END;
    ELSE
      Out.String("Value for key Files is not an array"); Out.Ln;
    END;
    someObj := someObj.next;
  END;
END fetchHttpsFiles;

PROCEDURE fetchGitDetails(someObj: Json.Obj; VAR gitRemote: vpkdepTree.RemoteGit; branchKey, remoteKey: Json.jString);
BEGIN
  WHILE someObj # NIL DO
    IF someObj IS Json.Obj THEN
      IF someObj.name^ = branchKey^ THEN
        COPY(someObj.value(Json.Str).str^, gitRemote^.branch);
      ELSIF someObj.name^ = remoteKey^ THEN
        COPY(someObj.value(Json.Str).str^, gitRemote^.URI);
      END;
    END;
    someObj := someObj.next;
  END;
END fetchGitDetails;

PROCEDURE getURIandType*(VAR d: vpkdepTree.Tdep);
VAR
  jsonstr, errstr: strUtils.pstring;
  tree, remoteValue: Json.Value;
  rootObj, someObj: Json.Obj;
  err: ARRAY ErrmessSize OF CHAR;
  b, fndRemSec: BOOLEAN;
  key, val, remote, keyLower: Json.jString;
  httpsRemote, httpsRemote2: vpkdepTree.RemoteHttps;
  httpRemote, httpRemote2: vpkdepTree.RemoteHttp;
  tmpRemote: vpkdepTree.Remote;
  gitRemote: vpkdepTree.RemoteGit;
BEGIN
  jsonstr := NIL;
  vpkStorage.json2pstring(d.name^, jsonstr);
  IF jsonstr # NIL THEN
    NEW(errstr, ErrmessSize);
    b := Json.Parse(tree, jsonstr^, errstr^);
    IF b THEN
      IF tree IS Json.Obj THEN
        rootObj := tree(Json.Obj);
        NEW(remote, Strings.Length(vpkSettings.rmtType) + 1);
        COPY(vpkSettings.rmtType, remote^);
        fndRemSec := FALSE;

        (* Find the "Remote" section *)
        WHILE (rootObj # NIL) & ~fndRemSec DO
          NEW(keyLower, LEN(rootObj.name^) + 1);
          COPY(rootObj.name^, keyLower^);
          ToLower(keyLower^);
          IF keyLower^ = "remote" THEN (* TODO, get rid of hardcoded string literals, decide with case *)
            fndRemSec := TRUE;
          ELSE
            rootObj := rootObj.next;
          END;
        END;

        IF fndRemSec THEN
          Out.String("Found 'Remote' section"); Out.Ln;
          remoteValue := rootObj.value;
          IF remoteValue IS Json.Obj THEN
            rootObj := remoteValue(Json.Obj);
            (* Process the "Remote" object *)
            WHILE rootObj # NIL DO
              key := rootObj.name;
              (* Convert key to lowercase *)
              NEW(keyLower, LEN(key^) + 1);
              COPY(key^, keyLower^);
              ToLower(keyLower^);
              IF rootObj.value IS Json.Str THEN
                val := rootObj.value(Json.Str).str;
                Out.String("Processing key: "); Out.String(key^); Out.Ln;
                Out.String("Value: "); Out.String(val^); Out.Ln;
                IF keyLower^ = "type" THEN (* type *) (* TODO, get rid of hardcoded string literals, decide with case *)
                  IF val^ = vpkSettings.rmtTypHttpsVal THEN
                    NEW(httpsRemote); d^.rmt := httpsRemote;
                    d^.Type := vpkSettings.https;
                    httpsRemote^.Files := List.Create();
                    Out.String("Set remote type to HTTPS"); Out.Ln;
                  ELSIF val^ = vpkSettings.rmtTypHttpVal THEN
                    NEW(httpRemote); d^.rmt := httpRemote;
                    d^.Type := vpkSettings.http;
                    httpRemote^.Files := List.Create();
                    Out.String("Set remote type to HTTP"); Out.Ln;
                  ELSIF val^ = vpkSettings.rmtTypGitVal THEN
                    NEW(gitRemote); d^.rmt := gitRemote;
                    d^.Type := vpkSettings.git;
                    gitRemote^.branch[0] := 0X; (* Ensure branch is set to an empty string *)
                    Out.String("Set remote type to GIT"); Out.Ln;
                  ELSE
                    Out.String("Unhandled remote type: "); Out.String(val^); Out.Ln; HALT(5);
                  END;
                ELSIF keyLower^ = "tag" THEN (* TODO, get rid of hardcoded string literals, decide with case *)
                  IF d^.rmt # NIL THEN
                    COPY(val^, d^.rmt(vpkdepTree.RemoteGit)^.tag); (* Use the tag field appropriately *)
                    Out.String("Set tag to "); Out.String(val^); Out.Ln;
                  ELSE
                    Out.String("d^.rmt is NIL when setting tag"); Out.Ln;
                  END;
                ELSIF keyLower^ = "path" THEN (* TODO, get rid of hardcoded string literals, decide with case *)
                  IF d^.rmt # NIL THEN
                    COPY(val^, d^.rmt^.URI);
                    Out.String("Set URI to "); Out.String(val^); Out.Ln;
                  ELSE
                    Out.String("d^.rmt is NIL when setting URI"); Out.Ln;
                  END;
                ELSE
                  Out.String("Unhandled key: "); Out.String(key^); Out.Ln;
                END;
              ELSE
                IF keyLower^ = "files" THEN (* TODO, get rid of hardcoded string literals, decide with case *)
                  IF (d^.rmt IS vpkdepTree.RemoteHttps) THEN
                    httpsRemote2 := d^.rmt(vpkdepTree.RemoteHttps);  (* Separate the cast *)
                    tmpRemote := httpsRemote2;
                    fetchHttpsFiles(rootObj, tmpRemote);
                  ELSIF (d^.rmt IS vpkdepTree.RemoteHttp) THEN
                    httpRemote2 := d^.rmt(vpkdepTree.RemoteHttp);
                    tmpRemote := httpRemote2;
                    fetchHttpsFiles(rootObj, tmpRemote);
                  ELSE
                    Out.String("Files section found but remote type is not HTTP(S)"); Out.Ln;
                  END;
                ELSE
                  Out.String("Value for key "); Out.String(key^); Out.String(" is not a string"); Out.Ln;
                END;
              END;
              rootObj := rootObj.next;
            END;
          ELSE
            Out.String("Remote value is not an object"); Out.Ln;
          END;
        ELSE
          Out.String("Remote section not found."); Out.Ln;
        END;
      ELSE
        Out.String("JSON root is not an object."); Out.Ln;
      END;
    ELSE
      Out.String("JSON parsing failed: "); Out.String(errstr^); Out.Ln;
    END;
  ELSE
    Out.String("No JSON string provided."); Out.Ln;
  END;
  IF d^.rmt = NIL THEN
    Out.String("deps remote is not set, this should not happen"); Out.Ln;
    HALT(5);
  END;
END getURIandType;


PROCEDURE getDeps*(VAR d: vpkdepTree.Tdep; VAR depstrlist: StringList.TStringList): LONGINT;
VAR
  jsonstr, errstr: strUtils.pstring;
  tree, depsValue, singleDep: Json.Value;
  rootObj, depObj: Json.Obj;
  depName, depVersion: Json.jString;
  foundDepSection: BOOLEAN;
BEGIN
  depstrlist := NIL;
  jsonstr := NIL;
  vpkStorage.json2pstring(d.name^, jsonstr);
  IF jsonstr # NIL THEN
    NEW(errstr, ErrmessSize);
    IF Json.Parse(tree, jsonstr^, errstr^) THEN
      IF tree IS Json.Obj THEN
        rootObj := tree(Json.Obj);
        (* searching for dependencies section *)
        foundDepSection := FALSE;
        REPEAT
          IF rootObj.name^ = vpkSettings.depTypKey THEN
            foundDepSection := TRUE;
          END;
          IF ~foundDepSection THEN rootObj := rootObj.next END
        UNTIL (rootObj = NIL) OR foundDepSection;
        IF foundDepSection THEN
          WHILE rootObj # NIL DO
            depsValue := rootObj.value;
            IF depsValue # NIL THEN
              IF depsValue IS Json.Obj THEN
                singleDep := depsValue(Json.Obj);
                WHILE singleDep # NIL DO
                  IF singleDep IS Json.Obj THEN
                    depObj := singleDep(Json.Obj);
                    depName := depObj.name;
                    depVersion := depObj.value(Json.Str).str;
                    IF depstrlist = NIL THEN depstrlist := StringList.Create() END;
                    depstrlist.AppendString(depstrlist, depName^);
                    singleDep := depObj.next;  (* Move to the next dependency *)
                  END;
                END;  (* End of inner WHILE loop for dependencies *)
                RETURN depstrlist.Count;
              END;  (* End of IF depsValue IS Json.Obj *)
            END;
            rootObj := rootObj.next;  (* Move to the next JSON object *)
          END;  (* End of WHILE rootObj # NIL loop *)
        ELSE
          RETURN 0; (* found no dependencies *)
        END;
      END;  (* End of IF tree IS Json.Obj *)
    ELSE
      Out.String("JSON parsing failed: "); Out.String(errstr^); Out.Ln;
    END;  (* End of IF Json.Parse *)
  ELSE
    Out.String("dependency '"); Out.String(d.name^); Out.String("' not found."); Out.Ln;
    RETURN -1; (* No such JSON file found *)
  END;  (* End of IF jsonstr # NIL *)
  RETURN 0;
END getDeps;

PROCEDURE setLocalProjectFile*(VAR filename: ARRAY OF CHAR);
BEGIN
  COPY(filename, currentLocalProjectFile);
END setLocalProjectFile;

PROCEDURE getBuildInfoFromFile*(VAR d: vpkdepTree.Tdep; VAR k, v: StringList.TStringList; VAR filename: ARRAY OF CHAR): BOOLEAN;
VAR
  jsonstr, errstr: strUtils.pstring;
  tree, buildValue, command, file: Json.Value;
  rootObj, buildStep: Json.Obj;
  buildArray: Json.Arr;
  cm, fl, bl, cmLower, flLower: Json.jString;
  b: BOOLEAN;
BEGIN
  k := NIL; v := NIL;
  b := FALSE;
  jsonstr := NIL;

  (* Read from specified file instead of package tree *)
  vpkStorage.fileToString(filename, jsonstr);

  IF jsonstr # NIL THEN
    NEW(errstr, ErrmessSize);
    b := Json.Parse(tree, jsonstr^, errstr^);
    IF b THEN
      IF tree IS Json.Obj THEN
        rootObj := tree(Json.Obj);
        NEW(bl, Strings.Length(vpkSettings.bldType) + 1); (* +1 for 0X *)
        COPY(vpkSettings.bldType, bl^);
        IF Json.ObjSelect(buildValue, rootObj, bl) THEN
          IF buildValue IS Json.Arr THEN
            buildArray := buildValue(Json.Arr);
            WHILE buildArray # NIL DO
              buildStep := buildArray.value(Json.Obj);
              NEW(cm, Strings.Length(vpkSettings.bldCommand) + 1); (* +1 for 0X *)
              NEW(fl, Strings.Length(vpkSettings.bldFile) + 1);    (* +1 for 0X *)
              COPY(vpkSettings.bldCommand, cm^);
              COPY(vpkSettings.bldFile, fl^);

              (* Handle build steps (same logic as original getBuildInfo) *)
              IF Json.ObjSelect(command, buildStep, cm) & Json.ObjSelect(file, buildStep, fl) THEN
                IF (command IS Json.Str) & (file IS Json.Str) THEN
                  IF k = NIL THEN k := StringList.Create() END;
                  IF v = NIL THEN v := StringList.Create() END;
                  k.AppendString(k, command(Json.Str).str^);
                  v.AppendString(v, file(Json.Str).str^);
                ELSE
                  Out.String("command and file must be strings"); Out.Ln;
                  HALT(5);
                END;
              ELSE
                Out.String("Failed to select 'command' or 'file' from build step"); Out.Ln;
              END;
              buildArray := buildArray.next;
            END;
          ELSE
            Out.String("Build section is not an array."); Out.Ln;
          END;
        ELSE
          Out.String("Build section not found."); Out.Ln;
        END;
      ELSE
        Out.String("JSON root is not an object."); Out.Ln;
      END;
    ELSE
      Out.String("JSON parsing failed: "); Out.String(errstr^); Out.Ln;
    END;
  ELSE
    Out.String("No JSON string provided."); Out.Ln;
  END;
  RETURN b;
END getBuildInfoFromFile;

PROCEDURE getDepsFromFile*(VAR d: vpkdepTree.Tdep; VAR depstrlist: StringList.TStringList): LONGINT;
VAR
  jsonstr, errstr: strUtils.pstring;
  tree, depsValue, singleDep: Json.Value;
  rootObj, depObj: Json.Obj;
  depName, depVersion: Json.jString;
  foundDepSection: BOOLEAN;
  filename: ARRAY 128 OF CHAR;
BEGIN
  depstrlist := NIL;
  jsonstr := NIL;

  (* For local projects, read from current directory's vipak.json *)
  IF currentLocalProjectFile = "" THEN
    COPY("vipak.json", filename);
  ELSE
    COPY(currentLocalProjectFile, filename);
  END;
  vpkStorage.fileToString(filename, jsonstr);

  IF jsonstr # NIL THEN
    NEW(errstr, ErrmessSize);
    IF Json.Parse(tree, jsonstr^, errstr^) THEN
      IF tree IS Json.Obj THEN
        rootObj := tree(Json.Obj);
        (* searching for dependencies section *)
        foundDepSection := FALSE;
        REPEAT
          IF rootObj.name^ = vpkSettings.depTypKey THEN
            foundDepSection := TRUE;
          END;
          IF ~foundDepSection THEN rootObj := rootObj.next END
        UNTIL (rootObj = NIL) OR foundDepSection;
        IF foundDepSection THEN
          WHILE rootObj # NIL DO
            depsValue := rootObj.value;
            IF depsValue # NIL THEN
              IF depsValue IS Json.Obj THEN
                singleDep := depsValue(Json.Obj);
                WHILE singleDep # NIL DO
                  IF singleDep IS Json.Obj THEN
                    depObj := singleDep(Json.Obj);
                    depName := depObj.name;
                    depVersion := depObj.value(Json.Str).str;
                    IF depstrlist = NIL THEN depstrlist := StringList.Create() END;
                    depstrlist.AppendString(depstrlist, depName^);
                    singleDep := depObj.next;  (* Move to the next dependency *)
                  END;
                END;  (* End of inner WHILE loop for dependencies *)
                RETURN depstrlist.Count;
              END;  (* End of IF depsValue IS Json.Obj *)
            END;
            rootObj := rootObj.next;  (* Move to the next JSON object *)
          END;  (* End of WHILE rootObj # NIL loop *)
        ELSE
          RETURN 0; (* found no dependencies *)
        END;
      END;  (* End of IF tree IS Json.Obj *)
    ELSE
      Out.String("JSON parsing failed: "); Out.String(errstr^); Out.Ln;
    END;  (* End of IF Json.Parse *)
  ELSE
    Out.String("local project file not found: "); Out.String(filename); Out.Ln;
    RETURN -1; (* No such JSON file found *)
  END;  (* End of IF jsonstr # NIL *)
  RETURN 0;
END getDepsFromFile;

END vpkJsonDepRetriever.
