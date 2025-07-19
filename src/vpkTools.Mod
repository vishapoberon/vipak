MODULE vpkTools;
IMPORT Strings, strUtils, Out;


PROCEDURE extractDomainFromUrl*(VAR url: ARRAY OF CHAR; VAR domain: ARRAY OF CHAR);
VAR
  start, i, j: INTEGER;
BEGIN
  start := 0;
  (* Skip protocol to find the start of the domain *)
  WHILE (start < LEN(url) - 1) & (url[start] # 0X) & ((url[start] # ':') OR (url[start+1] # '/')) DO
    INC(start);
  END;

  (* Skip the "://" part to actually reach the start of the domain *)
  INC(start, 3);  (* Assuming we stopped at ':', so we skip "://" *)

  i := start;
  (* Now 'start' is at the beginning of the domain, find the end of the domain *)
  WHILE (i < LEN(url)) & (url[i] # 0X) & (url[i] # '/') DO
    INC(i);
  END;

  (* Copy domain from url *)
  j := 0;
  WHILE (start < i) & (j < LEN(domain) - 1) DO
    domain[j] := url[start];
    INC(j); INC(start);
  END;
  domain[j] := 0X;  (* Ensure the domain string is null-terminated *)
END extractDomainFromUrl;

PROCEDURE extractPathFromUrl*(VAR url: ARRAY OF CHAR; VAR path: ARRAY OF CHAR);
VAR
  i, j, domainEnd: INTEGER;
  foundDomain: BOOLEAN;
BEGIN
  i := 0; foundDomain := FALSE;
  WHILE ~foundDomain & (i < LEN(url) - 1) & (url[i] # 0X) DO
    IF (url[i] = ':') & (url[i + 1] = '/') & (url[i + 2] = '/') THEN
      foundDomain := TRUE;
      i := i + 3;
    END;
    INC(i);
  END;

  IF foundDomain THEN
    domainEnd := i;
    WHILE (domainEnd < LEN(url)) & (url[domainEnd] # 0X) & (url[domainEnd] # '/') DO
      INC(domainEnd);
    END;

    j := 0;
    WHILE (domainEnd < LEN(url)) & (url[domainEnd] # 0X) & (j < LEN(path) - 1) DO
      path[j] := url[domainEnd];
      INC(j); INC(domainEnd);
    END;
    path[j] := 0X;
  ELSE
    path[0] := 0X; (* if no domain found *)
  END;
END extractPathFromUrl;

PROCEDURE extractFilenameFromUrl*(VAR url: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
VAR
  lastSlashPos: INTEGER;
BEGIN
  (* Find the position of the last '/' character in the URL *)
  lastSlashPos := -1;
  lastSlashPos := strUtils.Rpos(url, '/');

  (* Extract the part of the URL after the last '/' to get the filename *)
  IF lastSlashPos >= 0 THEN
    Strings.Extract(url, lastSlashPos + 1, Strings.Length(url) - lastSlashPos - 1, result);
  ELSE
    (* If '/' is not found, assume the entire URL is a filename *)
    COPY(url, result);
  END;
END extractFilenameFromUrl;

PROCEDURE extractRepoPathFromUrl*(VAR url: ARRAY OF CHAR; VAR repoPath: ARRAY OF CHAR);
(* Extracts full repository path from URL like:
   https://github.com/norayr/strutils -> github.com/norayr/strutils
   https://codeberg.org/user/project -> codeberg.org/user/project
*)
VAR
  start, i, j: INTEGER;
  found: BOOLEAN;
BEGIN
  (*
  Out.String("@@@ extractRepoPathFromUrl input: '"); Out.String(url); Out.String("'"); Out.Ln;
  *)
  start := 0;
  found := FALSE;
  repoPath[0] := 0X; (* Initialize to empty string *)

  (* Find the "://" pattern to skip protocol *)
  WHILE (start < LEN(url) - 2) & (url[start] # 0X) & ~found DO
    IF (url[start] = ':') & (url[start+1] = '/') & (url[start+2] = '/') THEN
      found := TRUE;
      start := start + 3; (* Skip "://" *)
    ELSE
      INC(start);
    END;
  END;
  (*
  Out.String("@@@ After skipping protocol, start="); Out.Int(start, 0); Out.Ln;
  *)
  IF ~found THEN
    (* No protocol found, assume the whole URL is the path *)
    COPY(url, repoPath);
    (*
    Out.String("@@@ No protocol found, using whole URL: '"); Out.String(repoPath); Out.String("'"); Out.Ln;
    *)
    RETURN;
  END;

  (* Find end of URL (exclude .git suffix if present) *)
  i := start;
  WHILE (i < LEN(url)) & (url[i] # 0X) DO
    INC(i);
  END;

  (*
  Out.String("@@@ End of URL at position: "); Out.Int(i, 0); Out.Ln;
  *)

  (* Remove .git suffix if present *)
  IF (i >= 4) & (url[i-4] = '.') & (url[i-3] = 'g') & (url[i-2] = 'i') & (url[i-1] = 't') THEN
    i := i - 4;
    (*
    Out.String("@@@ Removed .git suffix, new end: "); Out.Int(i, 0); Out.Ln;
    *)
  END;

  (* Copy domain + path *)
  j := 0;
  WHILE (start < i) & (j < LEN(repoPath) - 1) DO
    repoPath[j] := url[start];
    INC(j); INC(start);
  END;
  repoPath[j] := 0X;

  (*
  Out.String("@@@ extractRepoPathFromUrl output: '"); Out.String(repoPath); Out.String("'"); Out.Ln;
  *)
END extractRepoPathFromUrl;

END vpkTools.
