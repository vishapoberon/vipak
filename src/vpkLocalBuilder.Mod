MODULE vpkLocalBuilder;
IMPORT Files, Out, Strings, Platform, In,
       Json, StringList, List, strUtils,
       vpkStorage, vpkSettings, vpkdepTree, vpkInstaller, vpkEnv, vpkJsonDepRetriever,
       vpkResolver, vpkSyncer, vpkDot, vpkTools, UnixFS;

CONST
  DefaultProjectFile = "vipak.json";
  DefaultBuildDir = "build";
  ErrmessSize = 4096;

VAR
  eol: ARRAY 3 OF CHAR;

TYPE
  ProjectInfo = RECORD
    name: ARRAY 64 OF CHAR;
    author: ARRAY 64 OF CHAR;
    license: ARRAY 32 OF CHAR;
    version: ARRAY 16 OF CHAR;
    hasDeps: BOOLEAN;
    hasBuild: BOOLEAN;
  END;

PROCEDURE createTemplateModule(VAR projectName: ARRAY OF CHAR);
VAR
  filename: ARRAY 80 OF CHAR;
  content: ARRAY 512 OF CHAR;
  f: Files.File;
  r: Files.Rider;
  srcDir: UnixFS.fileInfo;
BEGIN
  (* Create src directory first *)
  COPY("src", srcDir.name);
  IF ~UnixFS.Exists(srcDir) THEN
    IF UnixFS.mkDir("src") THEN
      Out.String("Created src directory"); Out.Ln;
    ELSE
      Out.String("Failed to create src directory"); Out.Ln;
      RETURN;
    END;
  END;

  (* Create module filename in src directory *)
  COPY("src/", filename);
  Strings.Append(projectName, filename);
  Strings.Append(".Mod", filename);

  (* Create template module content *)
  COPY("MODULE ", content);
  Strings.Append(projectName, content);
  Strings.Append(";", content);
  Strings.Append(eol, content);
  Strings.Append("IMPORT Out;", content);
  Strings.Append(eol, content);
  Strings.Append(eol, content);
  Strings.Append("PROCEDURE main;", content);
  Strings.Append(eol, content);
  Strings.Append("BEGIN", content);
  Strings.Append(eol, content);
  Strings.Append('  Out.String("Hello from ', content);
  Strings.Append(projectName, content);
  Strings.Append('!"); Out.Ln;', content);
  Strings.Append(eol, content);
  Strings.Append('  Out.String("This project was built using vipak --local"); Out.Ln;', content);
  Strings.Append(eol, content);
  Strings.Append("END main;", content);
  Strings.Append(eol, content);
  Strings.Append(eol, content);
  Strings.Append("BEGIN", content);
  Strings.Append(eol, content);
  Strings.Append("  main", content);
  Strings.Append(eol, content);
  Strings.Append("END ", content);
  Strings.Append(projectName, content);
  Strings.Append(".", content);

  f := Files.New(filename);
  IF f # NIL THEN
    Files.Set(r, f, 0);
    Files.WriteBytes(r, content, Strings.Length(content));
    Files.Register(f);
    Files.Close(f);
    Out.String("Created template module: "); Out.String(filename); Out.Ln;
  ELSE
    Out.String("Failed to create template module: "); Out.String(filename); Out.Ln;
  END;
END createTemplateModule;

PROCEDURE createDefaultProject*(VAR filename: ARRAY OF CHAR);
VAR
  content: ARRAY 1024 OF CHAR;
  f: Files.File;
  r: Files.Rider;
  projectName: ARRAY 64 OF CHAR;
BEGIN
  (* Use a simple default project name *)
  COPY("myproject", projectName);

  (* Create default JSON content *)
  COPY('{', content);
  Strings.Append(eol, content);
  Strings.Append('    "Package": "', content);
  Strings.Append(projectName, content);
  Strings.Append('",', content);
  Strings.Append(eol, content);
  Strings.Append('    "Author": "Your Name",', content);
  Strings.Append(eol, content);
  Strings.Append('    "License": "GPL-3",', content);
  Strings.Append(eol, content);
  Strings.Append('    "Version": "0.1",', content);
  Strings.Append(eol, content);
  Strings.Append('    "Remote": {', content);
  Strings.Append(eol, content);
  Strings.Append('        "type": "git",', content);
  Strings.Append(eol, content);
  Strings.Append('        "path": "https://codeberg.org/yourname/', content);
  Strings.Append(projectName, content);
  Strings.Append('",', content);
  Strings.Append(eol, content);
  Strings.Append('        "tag": "0.1"', content);
  Strings.Append(eol, content);
  Strings.Append('    },', content);
  Strings.Append(eol, content);
  Strings.Append('    "Dependencies": {', content);
  Strings.Append(eol, content);
  Strings.Append('        "opts": "0.1"', content);
  Strings.Append(eol, content);
  Strings.Append('    },', content);
  Strings.Append(eol, content);
  Strings.Append('    "Build": [', content);
  Strings.Append(eol, content);
  Strings.Append('        {', content);
  Strings.Append(eol, content);
  Strings.Append('            "Command": "voc -m",', content);
  Strings.Append(eol, content);
  Strings.Append('            "File": "src/', content);
  Strings.Append(projectName, content);
  Strings.Append('.Mod"', content);
  Strings.Append(eol, content);
  Strings.Append('        }', content);
  Strings.Append(eol, content);
  Strings.Append('    ]', content);
  Strings.Append(eol, content);
  Strings.Append('}', content);

  f := Files.New(filename);
  IF f # NIL THEN
    Files.Set(r, f, 0);
    Files.WriteBytes(r, content, Strings.Length(content));
    Files.Register(f);
    Files.Close(f);
    Out.String("Created default project file: "); Out.String(filename); Out.Ln;
  ELSE
    Out.String("Failed to create project file: "); Out.String(filename); Out.Ln;
    HALT(1);
  END;
END createDefaultProject;

PROCEDURE fileExists(VAR filename: ARRAY OF CHAR): BOOLEAN;
VAR fi: UnixFS.fileInfo;
BEGIN
  COPY(filename, fi.name);
  RETURN UnixFS.Exists(fi);
END fileExists;

PROCEDURE parseProjectFile(VAR filename: ARRAY OF CHAR; VAR info: ProjectInfo): BOOLEAN;
VAR
  jsonstr, errstr: strUtils.pstring;
  tree, packageValue, authorValue, licenseValue, versionValue: Json.Value;
  depsValue, buildValue: Json.Value;
  rootObj: Json.Obj;
  packageKey, authorKey, licenseKey, versionKey: Json.jString;
  depsKey, buildKey: Json.jString;
  b: BOOLEAN;
BEGIN
  info.hasDeps := FALSE;
  info.hasBuild := FALSE;
  COPY("", info.name);
  COPY("", info.author);
  COPY("", info.license);
  COPY("", info.version);

  vpkStorage.fileToString(filename, jsonstr);
  IF jsonstr # NIL THEN
    NEW(errstr, ErrmessSize);
    b := Json.Parse(tree, jsonstr^, errstr^);
    IF b THEN
      IF tree IS Json.Obj THEN
        rootObj := tree(Json.Obj);

        (* Parse Package name *)
        NEW(packageKey, Strings.Length(vpkSettings.pkgTypKey) + 1);
        COPY(vpkSettings.pkgTypKey, packageKey^);
        IF Json.ObjSelect(packageValue, rootObj, packageKey) THEN
          IF packageValue IS Json.Str THEN
            COPY(packageValue(Json.Str).str^, info.name);
          END;
        END;

        (* Parse Author *)
        NEW(authorKey, 7); COPY("Author", authorKey^);
        IF Json.ObjSelect(authorValue, rootObj, authorKey) THEN
          IF authorValue IS Json.Str THEN
            COPY(authorValue(Json.Str).str^, info.author);
          END;
        END;

        (* Parse License *)
        NEW(licenseKey, 8); COPY("License", licenseKey^);
        IF Json.ObjSelect(licenseValue, rootObj, licenseKey) THEN
          IF licenseValue IS Json.Str THEN
            COPY(licenseValue(Json.Str).str^, info.license);
          END;
        END;

        (* Parse Version *)
        NEW(versionKey, 8); COPY("Version", versionKey^);
        IF Json.ObjSelect(versionValue, rootObj, versionKey) THEN
          IF versionValue IS Json.Str THEN
            COPY(versionValue(Json.Str).str^, info.version);
          END;
        END;

        (* Check for Dependencies *)
        NEW(depsKey, Strings.Length(vpkSettings.depTypKey) + 1);
        COPY(vpkSettings.depTypKey, depsKey^);
        IF Json.ObjSelect(depsValue, rootObj, depsKey) THEN
          info.hasDeps := TRUE;
        END;

        (* Check for Build section *)
        NEW(buildKey, Strings.Length(vpkSettings.bldType) + 1);
        COPY(vpkSettings.bldType, buildKey^);
        IF Json.ObjSelect(buildValue, rootObj, buildKey) THEN
          info.hasBuild := TRUE;
        END;

        RETURN TRUE;
      ELSE
        Out.String("JSON root is not an object."); Out.Ln;
      END;
    ELSE
      Out.String("JSON parsing failed: "); Out.String(errstr^); Out.Ln;
    END;
  ELSE
    Out.String("Failed to read project file."); Out.Ln;
  END;
  RETURN FALSE;
END parseProjectFile;

PROCEDURE createBuildDir(): BOOLEAN;
VAR
  fi: UnixFS.fileInfo;
BEGIN
  COPY(DefaultBuildDir, fi.name);
  IF ~UnixFS.Exists(fi) THEN
    IF UnixFS.mkDir(DefaultBuildDir) THEN
      Out.String("Created build directory: "); Out.String(DefaultBuildDir); Out.Ln;
    ELSE
      Out.String("Failed to create build directory: "); Out.String(DefaultBuildDir); Out.Ln;
      RETURN FALSE;
    END;
  END;
  RETURN TRUE;
END createBuildDir;

PROCEDURE resolveLocal(VAR projectFile: ARRAY OF CHAR): vpkdepTree.TdepTree;
VAR
  localDep: vpkdepTree.Tdep;
  depsList: StringList.TStringList;
  depName: StringList.pstring;
  combinedTree, subTree: vpkdepTree.TdepTree;
  currentDep: vpkdepTree.Tdep;
  i, j: LONGINT;
  found: BOOLEAN;
  graphName: ARRAY 32 OF CHAR;
  lst: StringList.TStringList;
  localName: ARRAY 16 OF CHAR;
BEGIN
  Out.Ln; Out.String("resolving dependencies for local project..."); Out.Ln;

  (* Set the local project file for dependency reading *)
  vpkJsonDepRetriever.setLocalProjectFile(projectFile);

  (* Create a dummy dependency object to read dependencies from local file *)
  COPY("local-project", localName);
  localDep := vpkdepTree.CreateDep(localName);

  (* Create combined dependency tree *)
  combinedTree := vpkdepTree.Create();

  (* Get direct dependencies from the local project file *)
  IF vpkJsonDepRetriever.getDepsFromFile(localDep, depsList) > 0 THEN
    Out.String("Found "); Out.Int(depsList.Count, 0); Out.String(" direct dependencies"); Out.Ln;

    (* Resolve each dependency using normal tree-based resolution *)
    i := 0;
    REPEAT
      depName := depsList.GetString(depsList, i);
      IF depName # NIL THEN
        Out.String("Resolving: "); Out.String(depName^); Out.Ln;

        (* Use normal vpkResolver.resolve for this dependency (it's in the tree) *)
        subTree := vpkResolver.resolve(depName^, vpkJsonDepRetriever.getDeps);

        (* Merge this subtree into combined tree (avoiding duplicates) *)
        j := 0;
        REPEAT
          currentDep := vpkdepTree.Get(subTree, j);
          IF currentDep # NIL THEN
            (* Check if this dependency is already in combined tree *)
            found := (combinedTree.GetByName(combinedTree, currentDep.name^) # NIL);
            IF ~found THEN
              vpkdepTree.AddCopy(combinedTree, currentDep);
            END;
          END;
          INC(j);
        UNTIL j = subTree.Count;
      END;
      INC(i);
    UNTIL i = depsList.Count;

    Out.String(" done! (:"); Out.Ln; Out.Ln;

    (* Show dependency graph like normal vipak *)
    vpkEnv.getGraphName(graphName);
    lst := vpkDot.tree2dot(combinedTree);
    Out.String("dependency graph:"); Out.Ln;
    Out.String("-----------------"); Out.Ln;
    StringList.DumpOut(lst);
    lst.Dump(lst, graphName);
    Out.String("-----------------"); Out.Ln;
    Out.String("(use 'dot -Tpng deps.dot > deps.png' to get the graph image)"); Out.Ln; Out.Ln;
    Out.String("dependencies will be installed in the following order:"); Out.Ln;
    i := 0;
    REPEAT
      currentDep := vpkdepTree.Get(combinedTree, i);
      IF currentDep # NIL THEN
        Out.String(currentDep.name^); Out.Ln;
      END;
      INC(i);
    UNTIL i = combinedTree.Count;
  ELSE
    Out.String("No dependencies found in project file."); Out.Ln;
  END;

  RETURN combinedTree;
END resolveLocal;

PROCEDURE buildDependencies(VAR projectFile: ARRAY OF CHAR);
VAR
  depTree: vpkdepTree.TdepTree;
  currentDep: vpkdepTree.Tdep;
  i, j: LONGINT;
  buildDir: ARRAY 128 OF CHAR;
  keys, values: StringList.TStringList;
  k, v: StringList.pstring;
  b: BOOLEAN;
  cmd, srcPath: StringList.pstring;
  res: INTEGER;
  repoPath: ARRAY 256 OF CHAR;
  node: List.Node;
  parentDir: ARRAY 8 OF CHAR;
  lastSlash, idx: INTEGER;  (* ADD: for filename removal *)
BEGIN
  (* Resolve all dependencies for local project *)
  depTree := resolveLocal(projectFile);

  IF depTree.Count > 0 THEN
    (* IMPROVED: Use simple build path *)
    COPY("build", buildDir);
    COPY("..", parentDir);

    i := 0;
    REPEAT
      currentDep := vpkdepTree.Get(depTree, i);
      IF currentDep # NIL THEN
        Out.String("Fetching: "); Out.String(currentDep.name^); Out.Ln;
        vpkJsonDepRetriever.getURIandType(currentDep);
        vpkSyncer.fetch(currentDep, buildDir);

        (* Now build the dependency *)
        Out.String("Building dependency: "); Out.String(currentDep.name^); Out.Ln;
        b := vpkJsonDepRetriever.getBuildInfo(currentDep, keys, values);
        IF b & (keys # NIL) & (values # NIL) THEN
          Out.String("Build info found for dependency: "); Out.String(currentDep.name^); Out.Ln;

          j := 0;
          REPEAT
            k := keys.GetString(keys, j);
            v := values.GetString(values, j);

            (* IMPROVED: Support Git, HTTPS, and HTTP sources *)
            IF currentDep^.rmt IS vpkdepTree.RemoteGit THEN
              vpkTools.extractRepoPathFromUrl(currentDep^.rmt.URI, repoPath);
            ELSIF currentDep^.rmt IS vpkdepTree.RemoteHttps THEN
              node := currentDep^.rmt(vpkdepTree.RemoteHttps)^.Files.Get(currentDep^.rmt(vpkdepTree.RemoteHttps)^.Files, 0);
              IF node # NIL THEN
                vpkTools.extractRepoPathFromUrl(node^.obj(vpkdepTree.File)^.URI, repoPath);
                (* IMPROVED: Remove filename for HTTP sources *)
                lastSlash := -1;
                idx := 0;
                WHILE (idx < Strings.Length(repoPath)) & (repoPath[idx] # 0X) DO
                  IF repoPath[idx] = '/' THEN lastSlash := idx; END;
                  INC(idx);
                END;
                IF lastSlash > 0 THEN
                  repoPath[lastSlash] := 0X;
                END;
              END;
            ELSIF currentDep^.rmt IS vpkdepTree.RemoteHttp THEN  (* ADD: HTTP support *)
              node := currentDep^.rmt(vpkdepTree.RemoteHttp)^.Files.Get(currentDep^.rmt(vpkdepTree.RemoteHttp)^.Files, 0);
              IF node # NIL THEN
                vpkTools.extractRepoPathFromUrl(node^.obj(vpkdepTree.File)^.URI, repoPath);
                (* IMPROVED: Remove filename for HTTP sources *)
                lastSlash := -1;
                idx := 0;
                WHILE (idx < Strings.Length(repoPath)) & (repoPath[idx] # 0X) DO
                  IF repoPath[idx] = '/' THEN lastSlash := idx; END;
                  INC(idx);
                END;
                IF lastSlash > 0 THEN
                  repoPath[lastSlash] := 0X;
                END;
              END;
            ELSE
              Out.String("WARNING: unsupported source type"); Out.Ln;
            END;

            (* Build source path - same logic as vpkInstaller *)
            srcPath := vpkEnv.getSrcRelPath(currentDep.name^, repoPath, v^);
            cmd := vpkEnv.mkCmd(k^, srcPath^);

            Out.String("Executing dependency build: "); Out.String(cmd^); Out.Ln;
            Out.String("Building dependency in: "); Out.String(buildDir); Out.Ln;

            (* IMPROVED: Continue on errors instead of HALT *)
            res := Platform.Chdir(buildDir);
            IF res # 0 THEN
              Out.String("Warning: Failed to change directory to "); Out.String(buildDir); Out.Ln;
            ELSE
              res := Platform.System(cmd^);
              IF res # 0 THEN
                Out.String("Warning: Dependency build failed with code: "); Out.Int(res, 0); Out.Ln;
              ELSE
                Out.String("Dependency build successful"); Out.Ln;
              END;

              (* Return to parent directory *)
              res := Platform.Chdir(parentDir);
            END;

            INC(j);
          UNTIL j = keys.Count;

        ELSE
          Out.String("No build information found for dependency: "); Out.String(currentDep.name^); Out.Ln;
        END;
      END;
      INC(i);
    UNTIL i = depTree.Count;

    Out.String("All dependencies processed!"); Out.Ln;
  END;
END buildDependencies;

PROCEDURE buildProject(VAR projectFile: ARRAY OF CHAR; info: ProjectInfo): BOOLEAN;
VAR
  dep: vpkdepTree.Tdep;
  keys, values: StringList.TStringList;
  k, v: StringList.pstring;
  b: BOOLEAN;
  cmd: ARRAY 256 OF CHAR;
  res, i: INTEGER;
  buildDirVar: ARRAY 64 OF CHAR;
BEGIN
  (* Create a dummy dependency object for build info extraction *)
  dep := vpkdepTree.CreateDep(info.name);

  (* Get build information using the procedure from vpkJsonDepRetriever *)
  b := vpkJsonDepRetriever.getBuildInfoFromFile(dep, keys, values, projectFile);

  IF b & (keys # NIL) & (values # NIL) THEN
    Out.String("Building project: "); Out.String(info.name); Out.Ln;

    (* Change to build directory *)
    COPY(DefaultBuildDir, buildDirVar);
    res := Platform.Chdir(buildDirVar);
    IF res # 0 THEN
      Out.String("Failed to change to build directory"); Out.Ln;
      RETURN FALSE;
    END;

    (* Execute build commands *)
    i := 0;
    REPEAT
      k := keys.GetString(keys, i);
      v := values.GetString(values, i);

      (* Create command: copy from parent directory if needed *)
      COPY(k^, cmd);
      Strings.Append(" ../", cmd);
      Strings.Append(v^, cmd);

      Out.String("Executing: "); Out.String(cmd); Out.Ln;
      res := Platform.System(cmd);
      IF res # 0 THEN
        Out.String("Build command failed with code: "); Out.Int(res, 0); Out.Ln;
        COPY("..", buildDirVar);
        res := Platform.Chdir(buildDirVar);
        RETURN FALSE;
      END;
      INC(i);
    UNTIL i = keys.Count;

    (* Restore original directory *)
    COPY("..", buildDirVar);
    res := Platform.Chdir(buildDirVar);
    Out.String("Build completed successfully!"); Out.Ln;
    RETURN TRUE;
  ELSE
    Out.String("No build information found in project file."); Out.Ln;
    RETURN FALSE;
  END;
END buildProject;

PROCEDURE buildLocal*(VAR projectFile: ARRAY OF CHAR);
VAR
  info: ProjectInfo;
  b: BOOLEAN;
BEGIN
  (* Check if project file exists *)
  IF ~fileExists(projectFile) THEN
    Out.String("Project file not found: "); Out.String(projectFile); Out.Ln;
    Out.String("Create one with 'vipak --init'"); Out.Ln;
    HALT(1);
  END;

  (* Parse project file *)
  b := parseProjectFile(projectFile, info);
  IF ~b THEN
    Out.String("Failed to parse project file: "); Out.String(projectFile); Out.Ln;
    HALT(1);
  END;

  Out.String("Building project: "); Out.String(info.name);
  Out.String(" v"); Out.String(info.version); Out.Ln;

  (* Create build directory *)
  IF ~createBuildDir() THEN
    HALT(1);
  END;

  (* Build dependencies if available - default behavior for local projects *)
  IF info.hasDeps THEN
    buildDependencies(projectFile);
  END;

  (* Build the project itself *)
  IF info.hasBuild THEN
    b := buildProject(projectFile, info);
    IF ~b THEN
      HALT(1);
    END;
  ELSE
    Out.String("No build instructions found in project file."); Out.Ln;
  END;
END buildLocal;

PROCEDURE init*;
VAR
  projectFile: ARRAY 64 OF CHAR;
  projectName: ARRAY 64 OF CHAR;
BEGIN
  COPY(DefaultProjectFile, projectFile);
  IF fileExists(projectFile) THEN
    Out.String("Project file already exists: "); Out.String(projectFile); Out.Ln;
    HALT(1);
  END;

  COPY("myproject", projectName);
  createDefaultProject(projectFile);
  createTemplateModule(projectName);

  Out.Ln;
  Out.String("Project initialized! You can now:"); Out.Ln;
  Out.String("  1. Edit src/"); Out.String(projectName); Out.String(".Mod with your code"); Out.Ln;
  Out.String("  2. Edit "); Out.String(projectFile); Out.String(" to configure build settings"); Out.Ln;
  Out.String("  3. Run 'vipak --local' to build the project"); Out.Ln;
END init;

BEGIN
  eol[0] := 0AX; eol[1] := 0X; (* Unix line ending *)
END vpkLocalBuilder.
