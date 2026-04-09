MODULE vpkMetaRetriever;

IMPORT
  StringList,
  vpkdepTree,
  vpkJsonDepRetriever,
  vpkTOMLDepRetriever;

CONST
  fmtAuto*      = 0;
  fmtJson*      = 1;
  fmtVipakfile* = 2;
  fmtToml*      = 3;

VAR
  preferredFormat*: INTEGER;

PROCEDURE SetPreferredFormat*(fmt: INTEGER);
BEGIN
  preferredFormat := fmt
END SetPreferredFormat;

PROCEDURE setLocalProjectFile*(VAR filename: ARRAY OF CHAR);
BEGIN
  vpkJsonDepRetriever.setLocalProjectFile(filename);
  vpkTOMLDepRetriever.setLocalProjectFile(filename)
END setLocalProjectFile;

PROCEDURE getDeps*(VAR d: vpkdepTree.Tdep; VAR depstrlist: StringList.TStringList): LONGINT;
BEGIN
  IF preferredFormat = fmtToml THEN
    RETURN vpkTOMLDepRetriever.getDeps(d, depstrlist)
  ELSE (* fmtJson, fmtAuto, fmtVipakfile *)
    RETURN vpkJsonDepRetriever.getDeps(d, depstrlist)
  END
END getDeps;

PROCEDURE getURIandType*(VAR d: vpkdepTree.Tdep);
BEGIN
  IF preferredFormat = fmtToml THEN
    vpkTOMLDepRetriever.getURIandType(d)
  ELSE
    vpkJsonDepRetriever.getURIandType(d)
  END
END getURIandType;

PROCEDURE getBuildInfo*(VAR d: vpkdepTree.Tdep; VAR k, v: StringList.TStringList): BOOLEAN;
BEGIN
  IF preferredFormat = fmtToml THEN
    RETURN vpkTOMLDepRetriever.getBuildInfo(d, k, v)
  ELSE
    RETURN vpkJsonDepRetriever.getBuildInfo(d, k, v)
  END
END getBuildInfo;

PROCEDURE getDepsFromFile*(VAR d: vpkdepTree.Tdep; VAR depstrlist: StringList.TStringList): LONGINT;
BEGIN
  IF preferredFormat = fmtToml THEN
    RETURN vpkTOMLDepRetriever.getDepsFromFile(d, depstrlist)
  ELSE
    RETURN vpkJsonDepRetriever.getDepsFromFile(d, depstrlist)
  END
END getDepsFromFile;

PROCEDURE getBuildInfoFromFile*(VAR d: vpkdepTree.Tdep; VAR k, v: StringList.TStringList; VAR filename: ARRAY OF CHAR): BOOLEAN;
BEGIN
  IF preferredFormat = fmtToml THEN
    RETURN vpkTOMLDepRetriever.getBuildInfoFromFile(d, k, v, filename)
  ELSE
    RETURN vpkJsonDepRetriever.getBuildInfoFromFile(d, k, v, filename)
  END
END getBuildInfoFromFile;

BEGIN
  preferredFormat := fmtToml
END vpkMetaRetriever.
