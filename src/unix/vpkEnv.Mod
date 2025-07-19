MODULE vpkEnv;
IMPORT Files, Platform, Strings, Out, vpkSettings, UnixFS, strTypes;

VAR
  conf-, confDir- : ARRAY 256 OF CHAR;
  pkgTreeDir-: POINTER TO ARRAY OF CHAR;

PROCEDURE getHome*(VAR path: ARRAY OF CHAR);
BEGIN
  IF ~(Platform.getEnv("HOME", path)) THEN
    Out.String("HOME variable is not found"); Out.Ln;
    HALT(1);
  END;
END getHome;

PROCEDURE getGraphName*(VAR grname: ARRAY OF CHAR);
BEGIN
  COPY (vpkSettings.graphName, grname);
END getGraphName;

PROCEDURE createIfNotThere*(VAR fileName: ARRAY OF CHAR);
VAR
  workName: ARRAY 512 OF CHAR;
  len: INTEGER;
BEGIN
  COPY(fileName, workName);

  (* Remove trailing slash for directory creation *)
  len := Strings.Length(workName);
  IF (len > 1) & (workName[len - 1] = '/') THEN
    workName[len - 1] := 0X;
  END;

  IF ~UnixFS.ExistsByName(workName) THEN
    IF ~UnixFS.mkDir(workName) THEN
      Out.String("failed to create directory "); Out.String(workName); Out.Ln; HALT(1);
    END;
  END;
END createIfNotThere;

(* Create directories recursively like mkdir -p *)
PROCEDURE mkDirRecursive*(VAR fullPath: ARRAY OF CHAR);
VAR
  currentPath: ARRAY 512 OF CHAR;
  component: ARRAY 128 OF CHAR;
  pos, nextPos: INTEGER;
  i: INTEGER;
BEGIN
  (*
  Out.String(">>> mkDirRecursive called with: '"); Out.String(fullPath); Out.String("'"); Out.Ln;
  *)

  COPY("", currentPath);
  pos := 0;

  (* Handle absolute paths starting with / *)
  IF (Strings.Length(fullPath) > 0) & (fullPath[0] = '/') THEN
    COPY("/", currentPath);
    pos := 1;
  END;

  WHILE pos < Strings.Length(fullPath) DO
    (* Find next '/' or end of string *)
    nextPos := pos;
    WHILE (nextPos < Strings.Length(fullPath)) & (fullPath[nextPos] # '/') DO
      INC(nextPos);
    END;

    (* Extract component *)
    IF nextPos > pos THEN
      i := 0;
      WHILE (pos < nextPos) & (i < LEN(component) - 1) DO
        component[i] := fullPath[pos];
        INC(i); INC(pos);
      END;
      component[i] := 0X;

      (* Append component to current path *)
      IF Strings.Length(currentPath) > 0 THEN
        IF currentPath[Strings.Length(currentPath) - 1] # '/' THEN
          Strings.Append("/", currentPath);
        END;
      END;
      Strings.Append(component, currentPath);

      (*
      Out.String(">>> Creating directory: '"); Out.String(currentPath); Out.String("'"); Out.Ln;
      *)

      (* Create directory if it doesn't exist - createIfNotThere handles trailing slashes *)
      createIfNotThere(currentPath);
    END;

    (* Skip the '/' *)
    IF (pos < Strings.Length(fullPath)) & (fullPath[pos] = '/') THEN
      INC(pos);
    END;
  END;

  (*
  Out.String(">>> mkDirRecursive completed"); Out.Ln;
  *)
END mkDirRecursive;

PROCEDURE getSrcRelPath*(VAR depName, repoPath, path0: ARRAY OF CHAR): strTypes.pstring;
VAR
  p: strTypes.pstring;
  len: INTEGER;
BEGIN
  (*
  Out.String("@@@ getSrcRelPath called with:"); Out.Ln;
  Out.String("@@@   depName: '"); Out.String(depName); Out.String("'"); Out.Ln;
  Out.String("@@@   repoPath: '"); Out.String(repoPath); Out.String("'"); Out.Ln;
  Out.String("@@@   path0: '"); Out.String(path0); Out.String("'"); Out.Ln;
  *)
  len := 16 + Strings.Length(path0) + Strings.Length(repoPath);
  NEW(p, len);
  COPY("", p^);  (* Start with empty string instead of "../" *)
  Strings.Append(vpkSettings.vpkDepDir, p^);
  Strings.Append("/", p^);
  Strings.Append(repoPath, p^);
  Strings.Append("/", p^);
  Strings.Append(path0, p^);
  (*
  Out.String("@@@   result: '"); Out.String(p^); Out.String("'"); Out.Ln;
  *)
  RETURN p;
END getSrcRelPath;

PROCEDURE mkConfDirPath(home: ARRAY OF CHAR; VAR path: ARRAY OF CHAR);
BEGIN
  COPY(home, confDir);
  Strings.Append("/", path);
  Strings.Append(vpkSettings.vpkConfDir, path);
END mkConfDirPath;

PROCEDURE mkBldDir*(prefix: ARRAY OF CHAR): strTypes.pstring;
VAR
  builddir: strTypes.pstring;
  ln : INTEGER;
BEGIN
  ln := 3 + Strings.Length(prefix) + Strings.Length(vpkSettings.vpkBldDir);
  NEW(builddir, ln);
  COPY(prefix, builddir^);
  createIfNotThere(builddir^);
  Strings.Append("/", builddir^);
  Strings.Append(vpkSettings.vpkBldDir, builddir^);
  createIfNotThere(builddir^);
  Strings.Append("/", builddir^);
  RETURN builddir
END mkBldDir;

PROCEDURE mkdefBldDir*(): strTypes.pstring;
VAR
  builddir: strTypes.pstring;
  ln: INTEGER;
  home: ARRAY 128 OF CHAR;
BEGIN
  getHome(home);
  ln := 2 + Strings.Length(home) + Strings.Length(vpkSettings.vpkPkgDir) + Strings.Length(vpkSettings.vpkBldDir);
  NEW(builddir, ln);
  COPY(home, builddir^);
  Strings.Append("/", builddir^);
  Strings.Append(vpkSettings.vpkPkgDir, builddir^);
  createIfNotThere(builddir^);
  Strings.Append("/", builddir^);
  Strings.Append(vpkSettings.vpkBldDir, builddir^);
  createIfNotThere(builddir^);
  RETURN builddir
END mkdefBldDir;

PROCEDURE mkdefPkgDirPath*(VAR repoPath, name, path: ARRAY OF CHAR);
VAR
  home: ARRAY 128 OF CHAR;
  finalPath: ARRAY 512 OF CHAR;
BEGIN
  getHome(home);

  (* Build: <home>/<vpkPkgDir>/deps/<repoPath>/<name>/ *)
  COPY(home, finalPath);
  Strings.Append("/", finalPath);
  Strings.Append(vpkSettings.vpkPkgDir, finalPath);
  Strings.Append("/", finalPath);
  Strings.Append(vpkSettings.vpkDepDir, finalPath);
  Strings.Append("/", finalPath);
  Strings.Append(repoPath, finalPath);
  Strings.Append("/", finalPath);
  Strings.Append(name, finalPath);

  (* Create all directories recursively *)
  mkDirRecursive(finalPath);

  (* Return the path with trailing slash *)
  COPY(finalPath, path);
  Strings.Append("/", path);
END mkdefPkgDirPath;

PROCEDURE mkPkgDirPath*(VAR repoPath, name, path: ARRAY OF CHAR);
VAR
  finalPath: ARRAY 512 OF CHAR;
  len: INTEGER;
BEGIN
  (*
  Out.String("=== DEBUG mkPkgDirPath START ==="); Out.Ln;
  Out.String("Input path: '"); Out.String(path); Out.String("'"); Out.Ln;
  Out.String("Input repoPath: '"); Out.String(repoPath); Out.String("'"); Out.Ln;
  Out.String("Input name: '"); Out.String(name); Out.String("'"); Out.Ln;
  *)

  (* Start with clean path *)
  COPY(path, finalPath);

  (* Remove trailing slashes *)
  len := Strings.Length(finalPath);
  WHILE (len > 1) & (finalPath[len - 1] = '/') DO
    finalPath[len - 1] := 0X;
    DEC(len);
  END;
  (*
  Out.String("After removing trailing slashes: '"); Out.String(finalPath); Out.String("'"); Out.Ln;
  *)

  (* Add /deps *)
  Strings.Append("/", finalPath);
  Strings.Append(vpkSettings.vpkDepDir, finalPath);
  (*
  Out.String("After adding deps: '"); Out.String(finalPath); Out.String("'"); Out.Ln;
  *)

  (* Add /<repoPath> - this already contains the package name! *)
  Strings.Append("/", finalPath);
  Strings.Append(repoPath, finalPath);
  (*
  Out.String("After adding repoPath: '"); Out.String(finalPath); Out.String("'"); Out.Ln;
  *)

  (* Create directories *)
  mkDirRecursive(finalPath);

  (* Return with trailing slash *)
  COPY(finalPath, path);
  Strings.Append("/", path);
  (*
  Out.String("Final output path: '"); Out.String(path); Out.String("'"); Out.Ln;
  Out.String("=== DEBUG mkPkgDirPath END ==="); Out.Ln;
  *)
END mkPkgDirPath;

PROCEDURE mkCmd*(VAR p0, p1: ARRAY OF CHAR): strTypes.pstring;
VAR
  cmd: strTypes.pstring;
  ln: INTEGER;
BEGIN
  ln := 2 + Strings.Length(p0) + Strings.Length(p1);
  NEW(cmd, ln);
  COPY(p0, cmd^);
  Strings.Append(" ", cmd^);
  Strings.Append(p1, cmd^);
  RETURN cmd
END mkCmd;

PROCEDURE setConfFileName;
VAR
  home: ARRAY 128 OF CHAR;
BEGIN
  getHome(home);
  mkConfDirPath(home, confDir);
  conf := confDir;
  Strings.Append("/", conf);
  Strings.Append(vpkSettings.vpkConfFile, conf);
END setConfFileName;

PROCEDURE getConfPath(VAR path: ARRAY OF CHAR);
BEGIN
  COPY(conf, path);
END getConfPath;

PROCEDURE getConfDir*(VAR path: ARRAY OF CHAR);
BEGIN
  COPY(confDir, path);
END getConfDir;

PROCEDURE getConfFile*(): Files.File;
VAR f: Files.File;
BEGIN
  f := Files.Old(conf);
  IF f = NIL THEN
    f := Files.New(conf)
  END;
  RETURN f;
END getConfFile;

PROCEDURE checkConfig*(): BOOLEAN;
VAR
  file : UnixFS.fileInfo;
BEGIN
  file.name := conf;
  RETURN UnixFS.Exists(file);
END checkConfig;

PROCEDURE setTreeDir*(VAR path: ARRAY OF CHAR);
VAR
  ln: INTEGER;
BEGIN
  ln := Strings.Length(path) + 1;
  NEW(pkgTreeDir, ln);
  COPY (path, pkgTreeDir^);
END setTreeDir;

PROCEDURE getTreeDir*(VAR path: ARRAY OF CHAR);
BEGIN
  IF pkgTreeDir = NIL THEN
    COPY(confDir, path);
    Strings.Append("/", path);
    Strings.Append(vpkSettings.vpkTreeDir, path);
  ELSE
    COPY(pkgTreeDir^, path);
  END
END getTreeDir;

PROCEDURE checkEnv*;
VAR
 file : UnixFS.fileInfo;
 tmp  : ARRAY 256 OF CHAR;
BEGIN
  file.name := conf;
  IF ~UnixFS.Exists(file) THEN
    (* Checking if ~/.vipack directory already exists *)
    file.name := confDir;
    IF ~UnixFS.Exists(file) THEN (* exists!!! *)
      Out.String("Creating directory "); Out.String(confDir);Out.Ln;
      IF ~UnixFS.mkDir(confDir) THEN
        Out.String("failed to create "); Out.String(confDir); Out.String(" directory"); Out.Ln;
        HALT(1);
      END;
    ELSE
      IF ~(UnixFS.dir IN file.attr) THEN
        Out.String(confDir); Out.String(" exists, but is not a directory"); Out.Ln;
        HALT(1);
      END;
    END;
  END;
    tmp := confDir;
    Strings.Append('/', tmp);
    Strings.Append(vpkSettings.vpkTreeDir, tmp);
    file.name := tmp;
    createIfNotThere(file.name);
END checkEnv;

BEGIN
  setConfFileName;
  pkgTreeDir := NIL;
END vpkEnv.
