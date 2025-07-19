MODULE vpkInstaller;
IMPORT In, Out, Platform,
       List, StringList,
       vpkResolver, vpkdepTree, vpkDot, vpkEnv, vpkJsonDepRetriever,vpkSyncer,
       vpkTools, vpkSettings;

PROCEDURE resolve*(VAR unit: ARRAY OF CHAR): vpkdepTree.TdepTree;
VAR
  tree: vpkdepTree.TdepTree;
  lst: StringList.TStringList;
  dep:  vpkdepTree.Tdep;
  i : LONGINT;
  graphName : ARRAY 32 OF CHAR;
BEGIN
  vpkEnv.getGraphName(graphName);
  Out.Ln; Out.String("resolving dependencies..."); Out.Ln;
  tree := vpkResolver.resolve(unit, vpkJsonDepRetriever.getDeps);
  Out.String(" done! (:"); Out.Ln; Out.Ln;
  lst  := vpkDot.tree2dot(tree);
  Out.String("dependency graph:"); Out.Ln;
  Out.String("-----------------"); Out.Ln;
  StringList.DumpOut(lst);
  lst.Dump(lst, graphName);
  Out.String("-----------------"); Out.Ln;
  Out.String("(use 'dot -Tpng deps.dot > deps.png' to get the graph image)"); Out.Ln; Out.Ln;
  Out.String("dependencies will be installed in the following order:"); Out.Ln;
  i := 0;
  REPEAT
    dep := vpkdepTree.Get(tree, i);
    Out.String(dep.name^); Out.Ln;
    INC(i)
  UNTIL i = tree.Count;
  RETURN tree
END resolve;

PROCEDURE ask();
VAR
  ch: CHAR;
BEGIN
  Out.String("would you like to merge these packages? (y/n) ");
  In.Char(ch);
  IF ch # 'y' THEN Out.Ln; Out.String('quitting'); Out.Ln; HALT(0); END
END ask;

PROCEDURE fetch*(VAR package:ARRAY OF CHAR; prefix: ARRAY OF CHAR; VAR pkgTree: ARRAY OF CHAR; a: BOOLEAN);
VAR
  depTree: vpkdepTree.TdepTree;
      dep: vpkdepTree.Tdep;
        i: LONGINT;
  builddir: StringList.pstring;
BEGIN
  (* Create build directory path *)
  IF prefix # "" THEN
    builddir := vpkEnv.mkBldDir(prefix)
  ELSE
    builddir := vpkEnv.mkdefBldDir();
  END;

  depTree := resolve(package);
  IF a THEN ask END;
  i := 0;
  REPEAT
    dep := vpkdepTree.Get(depTree, i);
    vpkJsonDepRetriever.getURIandType(dep);
    (* Pass build directory instead of prefix *)
    vpkSyncer.fetch(dep, builddir^);
    INC(i)
  UNTIL i = depTree.Count;
END fetch;

PROCEDURE build*(VAR package: ARRAY OF CHAR; prefix: ARRAY OF CHAR; VAR tree: ARRAY OF CHAR; a : BOOLEAN);
VAR
  depTree: vpkdepTree.TdepTree;
  dep: vpkdepTree.Tdep;
  i, j: LONGINT;
  keys, values: StringList.TStringList;
  k, v: StringList.pstring;
  b: BOOLEAN;
  builddir, cmd, srcPath: StringList.pstring;
  res: INTEGER;
  repoPath: ARRAY 256 OF CHAR; (* Changed from domain to repoPath *)
  node: List.Node;
BEGIN
  IF prefix # "" THEN
    builddir := vpkEnv.mkBldDir(prefix)
  ELSE
    builddir := vpkEnv.mkdefBldDir();
  END;
  depTree := resolve(package);
  IF a THEN ask END;
  i := 0;
  REPEAT
    dep := vpkdepTree.Get(depTree, i);
    vpkJsonDepRetriever.getURIandType(dep);
    (* Pass build directory instead of prefix *)
    vpkSyncer.fetch(dep, builddir^);
    b := FALSE;
    b := vpkJsonDepRetriever.getBuildInfo(dep, keys, values);
    IF b THEN
      Out.String("Build info found for the package: "); Out.String(dep.name^); Out.Ln;

      (* Ensure keys and values are not NIL *)
      IF keys = NIL THEN
        Out.String("Error: keys list is NIL."); Out.Ln;
        HALT(10);
      END;
      IF values = NIL THEN
        Out.String("Error: values list is NIL."); Out.Ln;
        HALT(10);
      END;

      Out.String("keys.Count = "); Out.Int(keys.Count, 0); Out.Ln;
      Out.String("values.Count = "); Out.Int(values.Count, 0); Out.Ln;
      j := 0;
      REPEAT
        Out.String("Processing build step "); Out.Int(j, 0); Out.Ln;
        IF dep^.rmt IS vpkdepTree.RemoteGit THEN
          (* Use extractRepoPathFromUrl instead of extractDomainFromUrl *)
          vpkTools.extractRepoPathFromUrl(dep^.rmt.URI, repoPath);
        ELSIF dep^.rmt IS vpkdepTree.RemoteHttps THEN
          node := dep^.rmt(vpkdepTree.RemoteHttps)^.Files.Get(dep^.rmt(vpkdepTree.RemoteHttps)^.Files, j);
          vpkTools.extractRepoPathFromUrl(node^.obj(vpkdepTree.File)^.URI, repoPath)
        ELSE
          Out.String("WARNING: building for neither git nor https sources not supported yet"); Out.Ln;
        END;
        IF j >= keys.Count THEN
          Out.String("Index out of bounds: keys.Count = "); Out.Int(keys.Count, 0); Out.String(", j = "); Out.Int(j, 0); Out.Ln;
          HALT(10);
        END;
        k := keys.GetString(keys, j);
        v := values.GetString(values, j);
        Out.String("Got key: "); Out.String(k^); Out.Ln;
        Out.String("Got value: "); Out.String(v^); Out.Ln;
        (* Use repoPath instead of domain, and deps/ prefix to reflect new structure *)
        srcPath := vpkEnv.getSrcRelPath(dep.name^, repoPath, v^);
        cmd := vpkEnv.mkCmd(k^, srcPath^);
        Out.String("Command: "); Out.String(cmd^); Out.Ln;
        Out.String("Building in "); Out.String(builddir^); Out.Ln;
        res := Platform.Chdir(builddir^);
        IF res # 0 THEN
          Out.String("Failed to change directory to "); Out.String(builddir^); Out.Ln; Out.String("This should never happen."); Out.Ln; HALT(66);
        END;
        res := Platform.System(cmd^);
        IF res # 0 THEN Out.String("Failed to run build command"); Out.Ln END;
        INC(j)
      UNTIL j = keys.Count;
    ELSE
      Out.String("No build info found for the package: "); Out.String(dep.name^); Out.Ln;
    END;
    INC(i);
  UNTIL i = depTree.Count;
END build;


END vpkInstaller.
