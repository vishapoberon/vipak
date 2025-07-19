MODULE vpkGit;
IMPORT Out, Strings, Platform, vpkEnv;

PROCEDURE pull*(VAR url : ARRAY OF CHAR; VAR dst : ARRAY OF CHAR; VAR branch: ARRAY OF CHAR);
VAR i : INTEGER;
    cmd : ARRAY 2048 OF CHAR;
    cleanDst: ARRAY 512 OF CHAR;
BEGIN
  (* Clean destination path - remove trailing slash *)
  COPY(dst, cleanDst);
  IF (Strings.Length(cleanDst) > 1) & (cleanDst[Strings.Length(cleanDst) - 1] = '/') THEN
    cleanDst[Strings.Length(cleanDst) - 1] := 0X;
  END;

  Out.String("*** GIT: Cloning to: '"); Out.String(cleanDst); Out.String("'"); Out.Ln;

  (* Remove directory if it exists to avoid conflicts *)
  cmd := "rm -rf ";
  Strings.Append(cleanDst, cmd);
  i := Platform.System(cmd);

  (* Use git clone directly - much simpler *)
  cmd := "git clone ";
  Strings.Append(url, cmd);
  IF branch # "" THEN
    Strings.Append(" --branch ", cmd);
    Strings.Append(branch, cmd);
  END;
  Strings.Append(" ", cmd);
  Strings.Append(cleanDst, cmd);

  Out.String("*** GIT: Executing: '"); Out.String(cmd); Out.String("'"); Out.Ln;
  i := Platform.System(cmd);
  IF i # 0 THEN
    Out.String("*** GIT: Command failed with exit code: "); Out.Int(i, 0); Out.Ln;
  ELSE
    Out.String("*** GIT: Clone successful"); Out.Ln;
  END;
END pull;

PROCEDURE syncTree*(url, branch: ARRAY OF CHAR);
VAR
  tmp: ARRAY 256 OF CHAR;
BEGIN
  vpkEnv.getTreeDir(tmp);
  pull(url, tmp, branch);
END syncTree;

PROCEDURE fetchRepo*(url: ARRAY OF CHAR; dst, branch: ARRAY OF CHAR);
BEGIN
  pull(url, dst, branch);
END fetchRepo;

END vpkGit.
