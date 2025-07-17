MODULE vipak;
IMPORT  Texts, Strings, Oberon, Out,
  vpkConf, vpkLogger, vpkSyncer, vpkInstaller, vpkdepTree, opts, StringList,
  vpkLocalBuilder;

PROCEDURE msgnopkg(VAR options: opts.Options);
BEGIN
      Out.String("you need to mention package name to resolve dependencies for it"); Out.Ln; Out.Ln;
      opts.showHelp(options);
END msgnopkg;

PROCEDURE main;
VAR
  deps, sync, fetch, ask, local, init, withDeps: BOOLEAN;
  package, prefix, pkgTree, localFile: ARRAY 128 OF CHAR;

  options: opts.Options;
  foptions: opts.Options;
  opt, fopt: opts.Option;

  depTree: vpkdepTree.TdepTree;
BEGIN
  IF ~vpkConf.configured() THEN vpkConf.mkDefConfig END;

  options := opts.createOptions();
  foptions := opts.createOptions();

  opt := opts.createOpt();
  opts.setOptName(opt, "-p");
  opts.setOptLName(opt, "--package");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptDesc(opt, "package name to download");
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-d");
  opts.setOptLName(opt, "--showdeps");
  opts.setOptHasVal(opt, FALSE);
  opts.setOptDesc(opt, "only resolve and show dependencies, do not fetch");
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-f");
  opts.setOptLName(opt, "--fetch");
  opts.setOptHasVal(opt, FALSE);
  opts.setOptDesc(opt, "only resolve and fetch, do not build");
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-a");
  opts.setOptLName(opt, "--ask");
  opts.setOptHasVal(opt, FALSE);
  opts.setOptDesc(opt, "ask before proceeding with build/fetch");
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-s");
  opts.setOptLName(opt, "--sync");
  opts.setOptHasVal(opt, FALSE);
  opts.setOptDesc(opt, "sync the package tree");
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-P");
  opts.setOptLName(opt, "--prefix");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptDesc(opt, "where to download and build packages");
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-t");
  opts.setOptLName(opt, "--tree");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptDesc(opt, "override the default package description tree");
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  (* New local build options *)
  opt := opts.createOpt();
  opts.setOptName(opt, "-l");
  opts.setOptLName(opt, "--local");
  opts.setOptHasVal(opt, FALSE);
  opts.setOptDesc(opt, "build local project from vipak.json file");
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-i");
  opts.setOptLName(opt, "--init");
  opts.setOptHasVal(opt, FALSE);
  opts.setOptDesc(opt, "create default vipak.json in current directory");
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-w");
  opts.setOptLName(opt, "--with-deps");
  opts.setOptHasVal(opt, FALSE);
  opts.setOptDesc(opt, "also build dependencies when building local project");
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  foptions := opts.populateOptions(options);
  IF opts.reqsSatisfied(options, foptions) THEN
    Out.String("required options provided"); Out.Ln;
  ELSE
    Out.String("required options not provided"); Out.Ln;
    opts.showHelp(options);
    HALT(3);
  END;
  Out.Ln;

  COPY("", package); COPY("", prefix); COPY("", pkgTree); COPY("vipak.json", localFile);
  deps := FALSE; sync := FALSE; fetch := FALSE; ask := FALSE;
  local := FALSE; init := FALSE; withDeps := FALSE;

  fopt := opts.createOpt();
  fopt := opts.findOpt("-d", foptions);
  IF fopt # NIL THEN deps := TRUE END;

  fopt := opts.createOpt();
  fopt := opts.findOpt("-a", foptions);
  IF fopt # NIL THEN ask := TRUE END;

  fopt := opts.createOpt();
  fopt := opts.findOpt("-f", foptions);
  IF fopt # NIL THEN fetch := TRUE END;

  fopt := opts.createOpt();
  fopt := opts.findOpt("-s", foptions);
  IF fopt # NIL THEN sync := TRUE END;

  fopt := opts.createOpt();
  fopt := opts.findOpt("-l", foptions);
  IF fopt # NIL THEN local := TRUE END;

  fopt := opts.createOpt();
  fopt := opts.findOpt("-i", foptions);
  IF fopt # NIL THEN init := TRUE END;

  fopt := opts.createOpt();
  fopt := opts.findOpt("-w", foptions);
  IF fopt # NIL THEN withDeps := TRUE END;

  opts.valOfOpt("-p", foptions, package);
  opts.valOfOpt("-P", foptions, prefix);
  IF prefix = "" THEN
    Out.String(" will use the default prefix location"); Out.Ln;
  END;
  opts.valOfOpt("-t", foptions, pkgTree);
  IF pkgTree = "" THEN
    Out.String(" will use the default package tree location"); Out.Ln;
  END;

  IF pkgTree # "" THEN vpkConf.setTreeDir(pkgTree) END;

  (* Handle new local build functionality *)
  IF init THEN
    Out.String("Initializing new vipak project..."); Out.Ln;
    vpkLocalBuilder.init
  ELSIF local THEN
    Out.String("Building local project from: "); Out.String(localFile); Out.Ln;
    vpkLocalBuilder.buildLocal(localFile, withDeps)
  ELSIF sync THEN
    vpkSyncer.sync
  ELSE
    IF package # "" THEN
      IF deps THEN
        depTree := vpkInstaller.resolve(package)
      ELSIF fetch THEN
        vpkInstaller.fetch(package, prefix, pkgTree, ask)
      ELSE
        vpkInstaller.build(package, prefix, pkgTree, ask)
      END
    ELSE
      msgnopkg(options)
    END
  END;

END main;

BEGIN
  main
END vipak.