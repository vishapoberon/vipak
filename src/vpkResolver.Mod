MODULE vpkResolver;
IMPORT Out, Strings, StringList, vpkdepTree;

TYPE
   pstr = StringList.pstring;
   Tdep = vpkdepTree.Tdep;
  Tdeps = vpkdepTree.Tdeps;

  TdepTree = vpkdepTree.TdepTree;

VAR rtvr: vpkdepTree.retriever;

PROCEDURE SplitDepSpec(VAR spec, depName, depVersion: ARRAY OF CHAR);
VAR
  i, l: INTEGER;
BEGIN
  COPY("", depName);
  COPY("", depVersion);
  l := Strings.Length(spec);
  i := 0;
  WHILE (i < l) & (spec[i] # ':') DO
    depName[i] := spec[i];
    INC(i);
  END;
  depName[i] := 0X;
  IF i < l THEN
    INC(i);
    WHILE i <= l DO
      depVersion[i - (Strings.Length(depName) + 1)] := spec[i];
      INC(i);
    END;
  END;
END SplitDepSpec;

PROCEDURE sameDep(VAR d1, d2: Tdep): BOOLEAN;
BEGIN
  IF (d1 = NIL) OR (d2 = NIL) THEN RETURN FALSE END;
  RETURN (d1.name^ = d2.name^) & (d1.version = d2.version);
END sameDep;

PROCEDURE treeContains(VAR d: Tdep; VAR depTree: TdepTree): BOOLEAN;
VAR
  res: BOOLEAN;
  i: INTEGER;
  d2: Tdep;
BEGIN
  res := FALSE;
  i := 0;
  REPEAT
    d2 := depTree.Get(depTree, i);
    IF d2 # NIL THEN
      IF sameDep(d, d2) THEN res := TRUE END;
    END;
    INC(i)
  UNTIL res OR (i >= depTree.Count);
  RETURN res;
END treeContains;

PROCEDURE treeContainsByName(VAR d: Tdep; VAR depTree: TdepTree): BOOLEAN;
VAR
  res: BOOLEAN;
  i: INTEGER;
  d2: Tdep;
BEGIN
  res := FALSE;
  i := 0;
  REPEAT
    d2 := depTree.Get(depTree, i);
    IF d2 # NIL THEN
      IF sameDep(d, d2) THEN res := TRUE END;
    END;
    INC(i)
  UNTIL res OR (i >= depTree.Count);
  RETURN res;
END treeContainsByName;

PROCEDURE mkDepTree(VAR d: Tdep; VAR depTree, met: TdepTree);
VAR
  depStrs: StringList.TStringList;
  t: Tdep;
  deps: Tdeps;
  p: pstr;
  i: INTEGER;
  rtrvRes: LONGINT;
  depName, depVersion: ARRAY 128 OF CHAR;
BEGIN
  vpkdepTree.Add(met, d);
    IF d.RetrieveDeps = NIL THEN Out.String("dep retriever method not installed"); Out.Ln; HALT(1) END;
    rtrvRes := d.RetrieveDeps(d, depStrs);
    IF rtrvRes = -1 THEN
      Out.Ln; Out.String("package named "); Out.String(d.name^); Out.String(" not found in the tree"); Out.Ln; HALT(61);
    END;
    IF rtrvRes = -2 THEN
      Out.Ln; Out.String(d.name^); Out.String(".json malformed: no 'Package' section."); Out.Ln;
      HALT(62);
    END;
    IF depStrs # NIL THEN
      NEW(deps, depStrs.Count);
      i := 0;
      REPEAT
        p := depStrs.GetString(depStrs, i);
        IF p # NIL THEN
          SplitDepSpec(p^, depName, depVersion);
          t := NIL;
          t := met.GetByNameVersion(met, depName, depVersion);
          IF t = NIL THEN
            IF depVersion = "" THEN
              t := vpkdepTree.CreateDep(depName)
            ELSE
              t := vpkdepTree.CreateDepVersioned(depName, depVersion)
            END;
            t.InstallRetriever(t, rtvr);
          END;
          deps[i] := t;
          IF ~treeContainsByName(t, depTree) THEN
            IF treeContainsByName(t, met) THEN
              Out.Ln; Out.String("curcular dependency: ");
              Out.String(d.name^);
              IF d.version # "" THEN Out.String(":"); Out.String(d.version) END;
              Out.String(" requires "); Out.String(t.name^);
              IF t.version # "" THEN Out.String(":"); Out.String(t.version) END;
              Out.Ln;
              Out.String("unable to continue."); Out.Ln;
              HALT(60)
            ELSE
              mkDepTree(t, depTree, met);
            END;
          END;
        END;
        INC(i);
      UNTIL i = depStrs.Count;
      d.AssignDeps(d, deps);
    END;
  vpkdepTree.AddCopy(depTree, d);
END mkDepTree;

PROCEDURE resolve*(first: ARRAY OF CHAR; r: vpkdepTree.retriever): TdepTree;
VAR
  depTree: TdepTree;
  met: TdepTree;
  dep:  Tdep;
  depName, depVersion: ARRAY 128 OF CHAR;
BEGIN
  rtvr := r;
  depTree := vpkdepTree.Create();
  met := vpkdepTree.Create(); (* for deps that we already met *)
  SplitDepSpec(first, depName, depVersion);
  IF depVersion = "" THEN
    dep := vpkdepTree.CreateDep(depName)
  ELSE
    dep := vpkdepTree.CreateDepVersioned(depName, depVersion)
  END;
  dep.InstallRetriever(dep, rtvr);
  mkDepTree(dep, depTree, met);
  RETURN depTree
END resolve;

END vpkResolver.
