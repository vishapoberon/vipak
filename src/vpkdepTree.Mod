MODULE vpkdepTree;
IMPORT Out, Strings,
       strUtils, List, StringList,
       vpkSettings;



TYPE

  pstring = strUtils.pstring;
  pstrings = strUtils.pstrings;

  Tdep*  = POINTER TO TdepDesc;
  Tdeps* = POINTER TO ARRAY OF Tdep;

  TdepTree* = POINTER TO TdepTreeDesc;

  TdepTreeDesc* = RECORD
     First- : Tdep;
      Last- : Tdep;
    Create* : PROCEDURE () : TdepTree;
      Free* : PROCEDURE (VAR l : TdepTree);
     Clear* : PROCEDURE (VAR l : TdepTree);
       Add* : PROCEDURE (VAR l : TdepTree; VAR s : Tdep);
       Get* : PROCEDURE (VAR l : TdepTree; i : LONGINT): Tdep;
 GetByName* : PROCEDURE (VAR l : TdepTree; VAR name : ARRAY OF CHAR): Tdep;
     Empty* : PROCEDURE (VAR l : TdepTree) : BOOLEAN;
     Count* : LONGINT;
  END;

  retriever- = PROCEDURE (VAR d: Tdep; VAR strlist: StringList.TStringList): LONGINT;

  Remote* = POINTER TO RemoteDesc;
  RemoteDesc* = RECORD
         URI* : ARRAY 512 OF CHAR;
  END;

 RemoteGit* = POINTER TO RemoteGitDesc;
 RemoteGitDesc* = RECORD(RemoteDesc)
          hash* : ARRAY 64 OF CHAR;
        branch* : ARRAY 32 OF CHAR;
           tag* : ARRAY 16 OF CHAR;
  END;

  File* = POINTER TO FileDesc;
  FileDesc* = RECORD (List.TObjectDesc)
     URI* : ARRAY 256 OF CHAR;
    auth* : BOOLEAN;
    username*, password*: ARRAY 32 OF CHAR;
    md5*  : ARRAY 33 OF CHAR;
  END;

  RemoteHttp* = POINTER TO RemoteHttpDesc;
  RemoteHttpDesc* = RECORD(RemoteDesc)
           Files* : List.TList;
  END;

  RemoteHttps* = POINTER TO RemoteHttpsDesc;
  RemoteHttpsDesc* = RECORD(RemoteDesc)
           Files* : List.TList;
  END;

  TdepDesc* = RECORD
         prev-, next-: Tdep;
         name- : pstring;
         deps- : Tdeps;
       Create* : PROCEDURE (VAR name: ARRAY OF CHAR): Tdep;
   AssignDeps* : PROCEDURE (VAR d: Tdep; VAR deps: Tdeps);
 RetrieveDeps- : retriever;
  InstallRetriever*: PROCEDURE(VAR d: Tdep; r: retriever);

       Type*   : LONGINT; (* from vpkSettings: http, https, gemini, git... *)
       rmt*    : Remote;
       END;

PROCEDURE AssignDeps*(VAR d: Tdep; VAR deps: Tdeps);
BEGIN
  d.deps := deps
END AssignDeps;

PROCEDURE InstallRetriever*(VAR d: Tdep; r: retriever);
BEGIN
  d.RetrieveDeps := r
END InstallRetriever;

PROCEDURE CreateDep*(VAR name: ARRAY OF CHAR): Tdep;
VAR
  dep: Tdep;
BEGIN
  NEW(dep);
  NEW(dep.name, Strings.Length(name) + 1);
  COPY(name, dep.name^);
  dep.AssignDeps := AssignDeps;
  dep.InstallRetriever := InstallRetriever;
  dep.RetrieveDeps := NIL;
  dep.rmt := NIL;
  RETURN dep
END CreateDep;

PROCEDURE list(VAR s : StringList.TStringList);
VAR e : StringList.Node;
    i : INTEGER;
BEGIN
   NEW(e);
   i := 0;
   REPEAT
      e := s.Get(s, i);
      IF e # NIL THEN Out.String (e.obj(StringList.TString).str^); Out.Ln END;
      (*Out.String (e.string); Out.Ln;*)
      INC(i);
   UNTIL i = s.Count - 1;
END list;

PROCEDURE listDeps*(VAR deps: Tdeps);
VAR
  l: LONGINT;
BEGIN
  l := 0;
  REPEAT
    Out.Int(l, 0); Out.String(": "); Out.String(deps[l].name^); Out.Ln;
    INC(l);
  UNTIL l = LEN(deps^) - 1;
END listDeps;

PROCEDURE Free*(VAR l : TdepTree);
 BEGIN
   l := NIL
 END Free;

PROCEDURE Clear*(VAR l : TdepTree);
 BEGIN
    l.First   := NIL;
    l.Count   := 0;
 END Clear;

PROCEDURE Empty* (VAR l : TdepTree) : BOOLEAN;
 BEGIN
    RETURN l.First = NIL
 END Empty;

PROCEDURE Add* (VAR l : TdepTree; VAR d: Tdep);
 BEGIN
    IF l.First = NIL THEN
       l.First := d;
    ELSE
       l.Last.next := d;
    END;
    l.Last := d;
    l.Last.next := NIL;
    INC(l.Count);
 END Add;

PROCEDURE AddCopy* (VAR l : TdepTree; VAR d: Tdep);
VAR
  new: Tdep;
  ln: INTEGER;
 BEGIN
 NEW(new);
 new.prev := d.prev; new.next := d.next;
 ln := Strings.Length(d.name^) + 1; NEW(new.name, ln); COPY(d.name^, new.name^);
 new.deps := d.deps;
 new.Create := d.Create; new.AssignDeps := d.AssignDeps;
 new.RetrieveDeps := d.RetrieveDeps;
 new.InstallRetriever := d.InstallRetriever;

    IF l.First = NIL THEN
       l.First := new;
    ELSE
       l.Last.next := new;
    END;
    l.Last := new;
    l.Last.next := NIL;
    INC(l.Count);
 END AddCopy;

PROCEDURE Get*(VAR l: TdepTree; inx: LONGINT): Tdep;
VAR
  i: LONGINT;
  d: Tdep;
BEGIN
  d := NIL;
  i := 0;
  IF (inx < l.Count) & (inx >= 0) THEN
    i := 0;
    d := l.First;
    WHILE i # inx DO
      IF d # NIL THEN d := d.next END;
      INC(i);
    END;
  END;
  RETURN d;
END Get;

PROCEDURE GetByName*(VAR l: TdepTree; VAR name: ARRAY OF CHAR): Tdep;
VAR
  i: LONGINT;
  d: Tdep;
  fnd: BOOLEAN;
BEGIN
  fnd := FALSE;
  i := 0;
  d := l.First;
  REPEAT
    IF d # NIL THEN
      IF d.name^ = name THEN
        fnd := TRUE;
        RETURN d;
      ELSE
        d := d.next
      END
    END;
    INC(i);
(*  UNTIL fnd OR (i >= l.Count );*)
  UNTIL fnd OR (d = NIL);
  RETURN NIL;  (* in case of this UNTIL it seems safe to RETURN d *)
END GetByName;

PROCEDURE Create* () : TdepTree;
    VAR l : TdepTree;
 BEGIN
    NEW(l);
    l.First   := NIL;
    l.Last    := NIL;
    l.Count   := 0;
    l.Add     := Add;
    l.Get     := Get;
  l.GetByName := GetByName;
    l.Clear   := Clear;
    l.Free    := Free;
    l.Empty   := Empty;
    RETURN(l);
 END Create;


END vpkdepTree.
