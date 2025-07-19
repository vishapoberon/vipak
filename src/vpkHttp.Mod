MODULE vpkHttp;
IMPORT Out, Platform, Strings,
       List, strTypes, http,
       vpkdepTree, vpkTools, vpkMD5Checker, vpkEnv;

PROCEDURE fetchFiles*(VAR dep: vpkdepTree.Tdep; dst: ARRAY OF CHAR);
VAR
  h: http.Client;
  answer: strTypes.pstring;
  domain, path: ARRAY 128 OF CHAR; port: ARRAY 8 OF CHAR;
  repoPath: ARRAY 256 OF CHAR;
  filename: ARRAY 64 OF CHAR;
  i, j: LONGINT;
  node: List.Node;
  bool, continueFetching: BOOLEAN;
  initialDst: ARRAY 512 OF CHAR;
  targetDir: ARRAY 512 OF CHAR;
  lastSlash: LONGINT;
  emptyName: ARRAY 1 OF CHAR;
  depthCount: INTEGER;
  startingDir: ARRAY 256 OF CHAR;
BEGIN
  COPY(Platform.CWD, startingDir);
  COPY(dst, initialDst);

  COPY("80", port);
  COPY("", emptyName);
  i := 0;
  continueFetching := TRUE;

  WHILE continueFetching DO
    node := dep^.rmt(vpkdepTree.RemoteHttp)^.Files.Get(dep^.rmt(vpkdepTree.RemoteHttp)^.Files, i);
    IF node # NIL THEN
      IF node^.obj(vpkdepTree.File) # NIL THEN
        Out.String("getting "); Out.String(node^.obj(vpkdepTree.File)^.URI); Out.Ln;

        (* Extract domain for connection *)
        vpkTools.extractDomainFromUrl(node^.obj(vpkdepTree.File)^.URI, domain);
        Out.String("connecting to "); Out.String(domain); Out.Ln;

        (* Extract full repository path for directory structure *)
        vpkTools.extractRepoPathFromUrl(node^.obj(vpkdepTree.File)^.URI, repoPath);

        (* Remove filename to get directory path *)
        lastSlash := -1;
        j := 0;
        WHILE (j < Strings.Length(repoPath)) & (repoPath[j] # 0X) DO
          IF repoPath[j] = '/' THEN lastSlash := j; END;
          INC(j);
        END;
        IF lastSlash > 0 THEN
          repoPath[lastSlash] := 0X;
        END;

        Out.String("repo path: "); Out.String(repoPath); Out.Ln;

        (* Use COPY of initialDst, not dst that gets modified *)
        COPY(initialDst, targetDir);
        vpkEnv.mkPkgDirPath(repoPath, emptyName, targetDir);

        (* Calculate return path by counting directory levels *)
        depthCount := 1; (* for "deps" *)
        j := 0;
        WHILE (j < Strings.Length(repoPath)) & (repoPath[j] # 0X) DO
          IF repoPath[j] = '/' THEN INC(depthCount); END;
          INC(j);
        END;

        vpkTools.extractPathFromUrl(node^.obj(vpkdepTree.File)^.URI, path);
        vpkTools.extractFilenameFromUrl(node^.obj(vpkdepTree.File)^.URI, filename);

        (* Change to target directory *)
        Out.String("will return to "); Out.Ln;
        Out.String(targetDir); Out.Ln;
        j := Platform.Chdir(targetDir);

        h := http.Create(domain, port, path);

        IF node^.obj(vpkdepTree.File)^.auth THEN
          Out.String("requires basic auth"); Out.Ln;
          Out.String("username: "); Out.String(node^.obj(vpkdepTree.File)^.username); Out.Ln;
          Out.String("password: "); Out.String(node^.obj(vpkdepTree.File)^.password); Out.Ln;

          h.appendAuthHdr(h, node^.obj(vpkdepTree.File)^.username, node^.obj(vpkdepTree.File)^.password);
        ELSE
          Out.String("does not require basic auth"); Out.Ln;
        END;

        (*h.Init(h);*)
        answer := h.Get(h);
        h.Save(h);
        bool := vpkMD5Checker.checkMD5(filename, node^.obj(vpkdepTree.File)^.md5);
        IF bool THEN Out.String("correct!") ELSE Out.String("incorrect!"); END; Out.Ln;

        (* Return to initial directory using calculated relative path *)
        Out.String("will return to "); Out.Ln;
        Out.String(startingDir); Out.Ln;
        j := Platform.Chdir(startingDir);
      ELSE
        Out.String("node^.obj(vpkdepTree.File) is NIL"); Out.Ln;
      END;
    ELSE
      Out.String("Node is NIL, stopping."); Out.Ln;
      continueFetching := FALSE;
    END;
    INC(i);
  END;

END fetchFiles;

END vpkHttp.
