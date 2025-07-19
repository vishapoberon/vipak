MODULE vpkSyncer;
IMPORT Strings, Out,
       strUtils, List,
       vpkSettings, vpkEnv, vpkConf, vpkGit, vpkdepTree, vpkTools, vpkHttps, vpkHttp;

PROCEDURE mkTreePath(VAR path: ARRAY OF CHAR);
BEGIN
  vpkEnv.getConfDir(path);
  Strings.Append('/', path);
  Strings.Append(vpkSettings.vpkTreeDir, path);
END mkTreePath;

PROCEDURE sync*;
VAR
  tree: vpkSettings.tree;
BEGIN
  (* Syncing *)
  vpkConf.getConfigTreeVal(tree);
    IF tree.typ = vpkSettings.git THEN
      vpkGit.syncTree(tree.url, tree.branch)
    ELSE
      Out.String("TODO: not a git url"); Out.Ln
    END;
END sync;

PROCEDURE fetch*(VAR dep: vpkdepTree.Tdep; dst: ARRAY OF CHAR);
VAR repoPath: ARRAY 256 OF CHAR;
    workingDst: ARRAY 512 OF CHAR; (* Local copy to modify *)
BEGIN
  (*
  Out.String("*** SYNCER: Starting fetch process..."); Out.Ln;
  Out.String("*** SYNCER: Input destination: '"); Out.String(dst); Out.String("'"); Out.Ln;
  *)
  COPY(dst, workingDst); (* Make a local copy to modify *)
  (*
  Out.String("*** SYNCER: Working destination: '"); Out.String(workingDst); Out.String("'"); Out.Ln;
  *)

  IF dep = NIL THEN
    Out.String("Dependency is NIL"); Out.Ln;
    HALT(1);
  END;
  IF dep^.rmt = NIL THEN
    Out.String("Dependency remote is NIL"); Out.Ln;
    HALT(5);
  ELSE
    IF dep^.rmt IS vpkdepTree.RemoteGit THEN
      (*
      Out.String("*** SYNCER: Remote type is Git"); Out.Ln;
      Out.String("*** SYNCER: Package name is: '"); Out.String(dep^.name^); Out.String("'"); Out.Ln;
      Out.String("*** SYNCER: Remote URI is: '"); Out.String(dep^.rmt^.URI); Out.String("'"); Out.Ln;
      *)

      vpkTools.extractRepoPathFromUrl(dep^.rmt^.URI, repoPath);
      (*
      Out.String("*** SYNCER: Extracted repo path: '"); Out.String(repoPath); Out.String("'"); Out.Ln;

      Out.String("*** SYNCER: About to call mkPkgDirPath with:"); Out.Ln;
      Out.String("***   repoPath = '"); Out.String(repoPath); Out.String("'"); Out.Ln;
      Out.String("***   name = '"); Out.String(dep^.name^); Out.String("'"); Out.Ln;
      Out.String("***   workingDst = '"); Out.String(workingDst); Out.String("'"); Out.Ln;
      *)

      (* Build the proper destination path *)
      IF Strings.Length(workingDst) = 0 THEN
        vpkEnv.mkdefPkgDirPath(repoPath, dep^.name^, workingDst);
      ELSE
        vpkEnv.mkPkgDirPath(repoPath, dep^.name^, workingDst);
      END;

      (*
      Out.String("*** SYNCER: After mkPkgDirPath, workingDst = '"); Out.String(workingDst); Out.String("'"); Out.Ln;
      Out.String("*** SYNCER: About to call git with destination: '"); Out.String(workingDst); Out.String("'"); Out.Ln;
      *)

      vpkGit.fetchRepo(dep^.rmt^.URI, workingDst, dep^.rmt(vpkdepTree.RemoteGit).branch);
    ELSIF dep^.rmt IS vpkdepTree.RemoteHttps THEN
      Out.String("Remote type is HTTPS"); Out.Ln;
      vpkHttps.fetchFiles(dep, workingDst);
    ELSIF dep^.rmt IS vpkdepTree.RemoteHttp THEN
      Out.String("Remote type is HTTP"); Out.Ln;
      vpkHttp.fetchFiles(dep, workingDst);
     ELSE
      Out.String("TODO: neither git nor https url"); Out.Ln;
      Out.String("not handled");
      Out.Ln;
    END;
  END;
  Out.String(Fetch process completed."); Out.Ln;
END fetch;

END vpkSyncer.
