MODULE vpkStorage;
IMPORT Files, Out, Strings,
  strUtils, vpkLogger, vpkEnv, UnixFS;

PROCEDURE WriteString(VAR r : Files.Rider; str : ARRAY OF CHAR);
BEGIN
   Files.WriteBytes(r, str, Strings.Length(str));
END WriteString;

PROCEDURE fileToString*(fileName: ARRAY OF CHAR; VAR returnString: strUtils.pstring);
VAR
    f: Files.File;
    r: Files.Rider;
    i, j: LONGINT;
BEGIN
    returnString := NIL;
    f := Files.Old(fileName);
    IF f # NIL THEN
      Files.Set(r, f, 0);
      i := Files.Length(f);
      NEW(returnString, i + 1);
      j := 0;
      REPEAT
        Files.Read(r, returnString^[j]);
        INC(j);
      UNTIL r.eof OR (j >= i);
      returnString^[j] := 0X;
    ELSE
      Out.String("file ");
      Out.String(fileName);
      Out.String(" not found");
      Out.Ln;
    END;
END fileToString;

PROCEDURE stringToFile*(VAR fileName, content: ARRAY OF CHAR): BOOLEAN;
VAR
    f: Files.File;
    r: Files.Rider;
BEGIN
    f := Files.New(fileName);

    IF f = NIL THEN
        vpkLogger.Log(fileName);
        vpkLogger.Log(" not found");
        vpkLogger.Ln;
        RETURN FALSE
    END;

    Files.Set(r, f, 0);
    vpkLogger.Log("Writing to file");
    vpkLogger.Log(fileName);
    vpkLogger.Log("-------------------");
    WriteString(r, content);

    Files.Register(f);
    Files.Close(f);
    RETURN TRUE;
END stringToFile;

PROCEDURE EndsWith(s: ARRAY OF CHAR; suffix: ARRAY OF CHAR): BOOLEAN;
VAR
  ls, lf, i: INTEGER;
BEGIN
  ls := Strings.Length(s);
  lf := Strings.Length(suffix);
  IF lf > ls THEN RETURN FALSE END;
  i := 0;
  WHILE i < lf DO
    IF s[ls - lf + i] # suffix[i] THEN RETURN FALSE END;
    INC(i)
  END;
  RETURN TRUE
END EndsWith;

PROCEDURE StripSuffix(s: ARRAY OF CHAR; suffix: ARRAY OF CHAR; VAR out: ARRAY OF CHAR): BOOLEAN;
VAR
  ls, lf, i: INTEGER;
BEGIN
  COPY("", out);
  ls := Strings.Length(s);
  lf := Strings.Length(suffix);
  IF lf > ls THEN RETURN FALSE END;
  i := 0;
  WHILE i < lf DO
    IF s[ls - lf + i] # suffix[i] THEN RETURN FALSE END;
    INC(i)
  END;
  i := 0;
  WHILE i < ls - lf DO
    out[i] := s[i];
    INC(i)
  END;
  out[i] := 0X;
  RETURN TRUE
END StripSuffix;

PROCEDURE BaseName(path: ARRAY OF CHAR; VAR base: ARRAY OF CHAR);
VAR
  i, start, j: INTEGER;
BEGIN
  start := 0;
  i := 0;
  WHILE path[i] # 0X DO
    IF path[i] = "/" THEN start := i + 1 END;
    INC(i)
  END;
  j := 0;
  i := start;
  WHILE path[i] # 0X DO
    base[j] := path[i];
    INC(i); INC(j)
  END;
  base[j] := 0X
END BaseName;

PROCEDURE DirName(path: ARRAY OF CHAR; VAR dir: ARRAY OF CHAR);
VAR
  i, lastSlash: INTEGER;
BEGIN
  lastSlash := -1;
  i := 0;
  WHILE path[i] # 0X DO
    IF path[i] = "/" THEN lastSlash := i END;
    INC(i)
  END;
  IF lastSlash < 0 THEN
    COPY("", dir)
  ELSE
    i := 0;
    WHILE i < lastSlash DO
      dir[i] := path[i];
      INC(i)
    END;
    dir[i] := 0X
  END
END DirName;

PROCEDURE LastPathComponent(path: ARRAY OF CHAR; VAR comp: ARRAY OF CHAR);
VAR
  dir: ARRAY 512 OF CHAR;
BEGIN
  DirName(path, dir);
  BaseName(dir, comp)
END LastPathComponent;

PROCEDURE ParseNat(s: ARRAY OF CHAR; VAR pos: INTEGER): INTEGER;
VAR n: INTEGER;
BEGIN
  n := 0;
  WHILE (s[pos] >= "0") & (s[pos] <= "9") DO
    n := n * 10 + (ORD(s[pos]) - ORD("0"));
    INC(pos)
  END;
  RETURN n
END ParseNat;

PROCEDURE CompareVersions*(a, b: ARRAY OF CHAR): INTEGER;
VAR
  ia, ib, va, vb: INTEGER;
BEGIN
  ia := 0; ib := 0;
  WHILE (a[ia] # 0X) OR (b[ib] # 0X) DO
    va := 0; vb := 0;
    IF (a[ia] >= "0") & (a[ia] <= "9") THEN va := ParseNat(a, ia) END;
    IF (b[ib] >= "0") & (b[ib] <= "9") THEN vb := ParseNat(b, ib) END;

    IF va < vb THEN RETURN -1 END;
    IF va > vb THEN RETURN 1 END;

    IF a[ia] = "." THEN INC(ia) END;
    IF b[ib] = "." THEN INC(ib) END;
  END;
  RETURN 0
END CompareVersions;

PROCEDURE versionFromPackageFileName*(path: ARRAY OF CHAR; VAR version: ARRAY OF CHAR): BOOLEAN;
VAR
  base, stem, pkg, prefix: ARRAY 512 OF CHAR;
  i, lp, ls: INTEGER;
  jsonSuffix: ARRAY 16 OF CHAR;
BEGIN
  COPY(".json", jsonSuffix);
  COPY("", version);
  BaseName(path, base);
  IF ~StripSuffix(base, jsonSuffix, stem) THEN RETURN FALSE END;
  LastPathComponent(path, pkg);

  COPY(pkg, prefix);
  Strings.Append("-", prefix);
  lp := Strings.Length(prefix);
  ls := Strings.Length(stem);
  IF ls < lp THEN RETURN FALSE END;

  i := 0;
  WHILE i < lp DO
    IF stem[i] # prefix[i] THEN RETURN FALSE END;
    INC(i)
  END;

  i := 0;
  WHILE stem[lp + i] # 0X DO
    version[i] := stem[lp + i];
    INC(i)
  END;
  version[i] := 0X;
  RETURN version # ""
END versionFromPackageFileName;

PROCEDURE findPackageJsonPath*(pkgName, reqVersion: ARRAY OF CHAR; VAR path: ARRAY OF CHAR): BOOLEAN;
VAR
  dirPath, fullPath, currentVersion, bestVersion: ARRAY 512 OF CHAR;
  lst: UnixFS.list;
  i: INTEGER;
  found: BOOLEAN;
  emptyVersion, jsonSuffix: ARRAY 16 OF CHAR;
BEGIN
  COPY("", path);
  COPY("", bestVersion);
  COPY("", emptyVersion);
  COPY(".json", jsonSuffix);
  found := FALSE;

  vpkEnv.getTreeDir(dirPath);
  Strings.Append("/", dirPath);
  Strings.Append(pkgName, dirPath);

  IF ~UnixFS.ExistsByName(dirPath) THEN RETURN FALSE END;

  UnixFS.ListDir(dirPath, lst);
  IF lst = NIL THEN RETURN FALSE END;

  i := 0;
  WHILE i < LEN(lst^) DO
    IF (lst^[i].name # ".") & (lst^[i].name # "..") THEN
      IF EndsWith(lst^[i].name, jsonSuffix) THEN
        COPY(dirPath, fullPath);
        Strings.Append("/", fullPath);
        Strings.Append(lst^[i].name, fullPath);
        IF versionFromPackageFileName(fullPath, currentVersion) THEN
          IF reqVersion # emptyVersion THEN
            IF currentVersion = reqVersion THEN
              COPY(fullPath, path);
              RETURN TRUE
            END
          ELSE
            IF ~found OR (CompareVersions(bestVersion, currentVersion) < 0) THEN
              COPY(currentVersion, bestVersion);
              COPY(fullPath, path);
              found := TRUE
            END
          END
        END
      END
    END;
    INC(i)
  END;
  RETURN found
END findPackageJsonPath;

PROCEDURE json2pstring*(pkgName, reqVersion: ARRAY OF CHAR; VAR pstr: strUtils.pstring);
VAR
  path: ARRAY 512 OF CHAR;
BEGIN
  pstr := NIL;
  IF findPackageJsonPath(pkgName, reqVersion, path) THEN
    fileToString(path, pstr)
  END
END json2pstring;

END vpkStorage.
