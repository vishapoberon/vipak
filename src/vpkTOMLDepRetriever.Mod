MODULE vpkTOMLDepRetriever;

IMPORT
  Out, Strings,
  List, StringList, strUtils,
  TOML, vpkStorage, vpkSettings, vpkdepTree;

VAR
  currentLocalProjectFile: ARRAY 256 OF CHAR;

(* Split a build step on the last space: cmd = everything before, file = last token *)
PROCEDURE SplitLastSpace(VAR step: ARRAY OF CHAR; VAR cmd, file: ARRAY OF CHAR): BOOLEAN;
VAR i, l, lastSp: INTEGER;
BEGIN
  l := Strings.Length(step);
  lastSp := -1;
  i := 0;
  WHILE i < l DO
    IF (step[i] = " ") OR (step[i] = 09X) THEN lastSp := i END;
    INC(i)
  END;
  IF lastSp < 0 THEN RETURN FALSE END;
  i := 0;
  WHILE i < lastSp DO cmd[i] := step[i]; INC(i) END;
  cmd[i] := 0X;
  TOML.TrimRight(cmd);
  i := lastSp + 1; l := 0;
  WHILE step[i] # 0X DO file[l] := step[i]; INC(i); INC(l) END;
  file[l] := 0X;
  TOML.TrimLeft(file);
  RETURN (cmd[0] # 0X) & (file[0] # 0X)
END SplitLastSpace;

(* Split run value on newlines and ; into (cmd, file) pairs *)
PROCEDURE ParseBuildRun(VAR run: ARRAY OF CHAR; VAR k, v: StringList.TStringList): BOOLEAN;
VAR
  i, j, l: INTEGER;
  ch:  CHAR;
  step, cmd, file: ARRAY 512 OF CHAR;
  done: BOOLEAN;
BEGIN
  k := NIL; v := NIL;
  l := Strings.Length(run);
  i := 0; j := 0;
  step[0] := 0X;
  done := FALSE;
  WHILE ~done DO
    IF i >= l THEN
      ch := 0X; done := TRUE
    ELSE
      ch := run[i]; INC(i)
    END;
    IF (ch = 0AX) OR (ch = ";") OR (ch = 0X) THEN
      step[j] := 0X;
      TOML.Trim(step);
      IF step[0] # 0X THEN
        IF SplitLastSpace(step, cmd, file) THEN
          IF k = NIL THEN k := StringList.Create() END;
          IF v = NIL THEN v := StringList.Create() END;
          k.AppendString(k, cmd);
          v.AppendString(v, file)
        END
      END;
      j := 0; step[0] := 0X
    ELSE
      IF j < 511 THEN step[j] := ch; INC(j) END
    END
  END;
  RETURN (k # NIL) & (k.Count > 0)
END ParseBuildRun;

PROCEDURE getDepsFromContent(VAR content: ARRAY OF CHAR; VAR depstrlist: StringList.TStringList): LONGINT;
VAR
  doc: TOML.Doc;
  sec: TOML.Section;
  fld: TOML.Field;
  spec: ARRAY 256 OF CHAR;
  secName: ARRAY 16 OF CHAR;
BEGIN
  depstrlist := NIL;
  doc := TOML.Parse(content);
  COPY("deps", secName);
  sec := TOML.GetSection(doc, secName);
  IF sec = NIL THEN RETURN 0 END;
  fld := sec^.first;
  WHILE fld # NIL DO
    IF fld^.key[0] # 0X THEN
      IF fld^.value[0] # 0X THEN
        COPY(fld^.key, spec);
        Strings.Append(":", spec);
        Strings.Append(fld^.value, spec)
      ELSE
        COPY(fld^.key, spec)
      END;
      IF depstrlist = NIL THEN depstrlist := StringList.Create() END;
      depstrlist.AppendString(depstrlist, spec)
    END;
    fld := fld^.next
  END;
  IF depstrlist = NIL THEN RETURN 0 END;
  RETURN depstrlist.Count
END getDepsFromContent;

PROCEDURE getURIandTypeFromContent(VAR content: ARRAY OF CHAR; VAR d: vpkdepTree.Tdep): BOOLEAN;
VAR
  doc:         TOML.Doc;
  sec:         TOML.Section;
  typ:         ARRAY 32 OF CHAR;
  uri:         ARRAY 512 OF CHAR;
  tag:         ARRAY 64 OF CHAR;
  md5:         ARRAY 34 OF CHAR;
  authtype:    ARRAY 32 OF CHAR;
  user:        ARRAY 32 OF CHAR;
  pass:        ARRAY 32 OF CHAR;
  typLow:      ARRAY 32 OF CHAR;
  atLow:       ARRAY 32 OF CHAR;
  gitRemote:   vpkdepTree.RemoteGit;
  httpsRemote: vpkdepTree.RemoteHttps;
  httpRemote:  vpkdepTree.RemoteHttp;
  httpsFile:   vpkdepTree.File;
  secName:     ARRAY 16 OF CHAR;
  keyName:     ARRAY 16 OF CHAR;
BEGIN
  doc := TOML.Parse(content);
  COPY("remote", secName);
  sec := TOML.GetSection(doc, secName);
  IF sec = NIL THEN RETURN FALSE END;

  COPY("", typ);
  COPY("type", keyName); IF ~TOML.GetField(sec, keyName, typ) THEN END;
  COPY(typ, typLow); TOML.ToLower(typLow);

  IF typLow = "git" THEN
    COPY("", uri); COPY("", tag);
    COPY("uri",  keyName);
    IF ~TOML.GetField(sec, keyName, uri) THEN
      COPY("path", keyName); IF ~TOML.GetField(sec, keyName, uri) THEN END
    END;
    COPY("tag", keyName); IF ~TOML.GetField(sec, keyName, tag) THEN END;
    NEW(gitRemote);
    d^.rmt    := gitRemote;
    d^.Type   := vpkSettings.git;
    COPY(uri, gitRemote^.URI);
    COPY(tag, gitRemote^.tag);
    gitRemote^.branch[0] := 0X;
    RETURN TRUE

  ELSIF typLow = "https" THEN
    NEW(httpsRemote);
    d^.rmt  := httpsRemote;
    d^.Type := vpkSettings.https;
    httpsRemote^.Files := List.Create();
    WHILE sec # NIL DO
      COPY("", uri); COPY("", md5); COPY("", authtype); COPY("", user); COPY("", pass);
      COPY("uri",      keyName); IF ~TOML.GetField(sec, keyName, uri)      THEN END;
      COPY("md5",      keyName); IF ~TOML.GetField(sec, keyName, md5)      THEN END;
      COPY("authtype", keyName); IF ~TOML.GetField(sec, keyName, authtype) THEN END;
      COPY("user",     keyName); IF ~TOML.GetField(sec, keyName, user)     THEN END;
      COPY("password", keyName); IF ~TOML.GetField(sec, keyName, pass)     THEN END;
      IF uri[0] # 0X THEN
        NEW(httpsFile);
        COPY(uri, httpsFile^.URI);
        COPY(md5, httpsFile^.md5);
        COPY(authtype, atLow); TOML.ToLower(atLow);
        IF atLow = "basicauth" THEN
          httpsFile^.auth := TRUE;
          COPY(user, httpsFile^.username);
          COPY(pass, httpsFile^.password)
        ELSE
          httpsFile^.auth := FALSE
        END;
        httpsRemote^.Files.Append(httpsRemote^.Files, httpsFile)
      END;
      sec := TOML.GetNextSection(sec, secName)
    END;
    RETURN TRUE

  ELSIF typLow = "http" THEN
    NEW(httpRemote);
    d^.rmt  := httpRemote;
    d^.Type := vpkSettings.http;
    httpRemote^.Files := List.Create();
    WHILE sec # NIL DO
      COPY("", uri); COPY("", md5); COPY("", authtype); COPY("", user); COPY("", pass);
      COPY("uri",      keyName); IF ~TOML.GetField(sec, keyName, uri)      THEN END;
      COPY("md5",      keyName); IF ~TOML.GetField(sec, keyName, md5)      THEN END;
      COPY("authtype", keyName); IF ~TOML.GetField(sec, keyName, authtype) THEN END;
      COPY("user",     keyName); IF ~TOML.GetField(sec, keyName, user)     THEN END;
      COPY("password", keyName); IF ~TOML.GetField(sec, keyName, pass)     THEN END;
      IF uri[0] # 0X THEN
        NEW(httpsFile);
        COPY(uri, httpsFile^.URI);
        COPY(md5, httpsFile^.md5);
        COPY(authtype, atLow); TOML.ToLower(atLow);
        IF atLow = "basicauth" THEN
          httpsFile^.auth := TRUE;
          COPY(user, httpsFile^.username);
          COPY(pass, httpsFile^.password)
        ELSE
          httpsFile^.auth := FALSE
        END;
        httpRemote^.Files.Append(httpRemote^.Files, httpsFile)
      END;
      sec := TOML.GetNextSection(sec, secName)
    END;
    RETURN TRUE
  END;

  Out.String("vpkTOMLDepRetriever: unsupported remote type: "); Out.String(typ); Out.Ln;
  RETURN FALSE
END getURIandTypeFromContent;

PROCEDURE getBuildInfoFromContent(VAR content: ARRAY OF CHAR; VAR k, v: StringList.TStringList): BOOLEAN;
VAR
  doc:     TOML.Doc;
  sec:     TOML.Section;
  run:     ARRAY 4096 OF CHAR;
  secName, keyName: ARRAY 16 OF CHAR;
BEGIN
  k := NIL; v := NIL;
  doc := TOML.Parse(content);
  COPY("build", secName);
  sec := TOML.GetSection(doc, secName);
  IF sec = NIL THEN RETURN FALSE END;
  COPY("run", keyName);
  IF ~TOML.GetField(sec, keyName, run) THEN RETURN FALSE END;
  RETURN ParseBuildRun(run, k, v)
END getBuildInfoFromContent;

PROCEDURE getDeps*(VAR d: vpkdepTree.Tdep; VAR depstrlist: StringList.TStringList): LONGINT;
VAR content: strUtils.pstring;
BEGIN
  depstrlist := NIL;
  vpkStorage.vipak2pstring(d.name^, d.version, content);
  IF content = NIL THEN
    Out.String("No .vipak file found for: "); Out.String(d.name^); Out.Ln;
    RETURN -1
  END;
  RETURN getDepsFromContent(content^, depstrlist)
END getDeps;

PROCEDURE getURIandType*(VAR d: vpkdepTree.Tdep);
VAR content: strUtils.pstring;
BEGIN
  vpkStorage.vipak2pstring(d.name^, d.version, content);
  IF content = NIL THEN
    Out.String("No .vipak file found for: "); Out.String(d.name^); Out.Ln;
    RETURN
  END;
  IF ~getURIandTypeFromContent(content^, d) THEN
    Out.String("Failed to get remote info from .vipak for: "); Out.String(d.name^); Out.Ln
  END
END getURIandType;

PROCEDURE getBuildInfo*(VAR d: vpkdepTree.Tdep; VAR k, v: StringList.TStringList): BOOLEAN;
VAR content: strUtils.pstring;
BEGIN
  vpkStorage.vipak2pstring(d.name^, d.version, content);
  IF content = NIL THEN k := NIL; v := NIL; RETURN FALSE END;
  RETURN getBuildInfoFromContent(content^, k, v)
END getBuildInfo;

PROCEDURE setLocalProjectFile*(VAR filename: ARRAY OF CHAR);
BEGIN
  COPY(filename, currentLocalProjectFile)
END setLocalProjectFile;

PROCEDURE getDepsFromFile*(VAR d: vpkdepTree.Tdep; VAR depstrlist: StringList.TStringList): LONGINT;
VAR
  content: strUtils.pstring;
  filename: ARRAY 256 OF CHAR;
BEGIN
  depstrlist := NIL;
  IF currentLocalProjectFile[0] = 0X THEN
    COPY("vipak.vipak", filename)
  ELSE
    COPY(currentLocalProjectFile, filename)
  END;
  vpkStorage.fileToString(filename, content);
  IF content = NIL THEN RETURN -1 END;
  RETURN getDepsFromContent(content^, depstrlist)
END getDepsFromFile;

PROCEDURE getBuildInfoFromFile*(VAR d: vpkdepTree.Tdep; VAR k, v: StringList.TStringList; VAR filename: ARRAY OF CHAR): BOOLEAN;
VAR content: strUtils.pstring;
BEGIN
  vpkStorage.fileToString(filename, content);
  IF content = NIL THEN k := NIL; v := NIL; RETURN FALSE END;
  RETURN getBuildInfoFromContent(content^, k, v)
END getBuildInfoFromFile;

BEGIN
  currentLocalProjectFile[0] := 0X
END vpkTOMLDepRetriever.
