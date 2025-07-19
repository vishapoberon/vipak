![](https://xn--y9azesw6bu.xn--y9a3aq/media/uploads/2022/01/19/4b650ab4-2e97-45f8-8fd3-af1c726399c0.png)

vipak
======

vipak is a language or dependency agnostic package manager.

currently it has a backend to retrieve dependencies from the [vipak tree](https://codeberg.org/vishapoberon/vipatsar).

that is a list of json files, each containing information about the package dependencies, where to download the packages, and how to build those.

build
=====

requirements: git, gmake, cc, voc

`git clone https://codeberg.org/vishapoberon/vipak`
`cd vipak`
`gmake`

or on freebsd:

`gmake -f makefile_freebsd`

usage
=====

try `vipak --help`.

some examples:

`vipak -s` — syncs the default package tree to `~/.vipak/vipatsar`.

`vipak -d -p irc_bot` — only resolves/shows dependencies of the package `irc_bot`, does not download or build packages.

`vipak -f -p irc_bot` — resolves and fetches required packages.

`vipak -p irc_bot` — will build the package and dependencies in the default prefix: `~/vpkLocal`

`vipak -a -p irc_bot` — ask for confirmation before building the package and dependencies in the default prefix: `~/vpkLocal`

`vipak -p irc_bot -P /tmp/coolprefix` — will do the same in the custom prefix.

`vipak -p irc_bot -P /tmp/coolprefix -t /tmp/myothertree` — the same, but the dependency resolution will be conducted by using custom package description tree.

local project builds
====

see in details [here](local_build.md)


