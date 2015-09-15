# If a fork of these scripts is specified, use that GitHub user instead
fork_user=${FORK_USER:-ocaml}

# If a branch of these scripts is specified, use that branch instead of 'master'
fork_branch=${FORK_BRANCH:-master}

### Bootstrap

set -uex






TMP_BUILD=$(mktemp -d 2>/dev/null || mktemp -d -t 'travistmpdir')

cp .travis-ocaml.sh ${TMP_BUILD}
cp yorick.mli ${TMP_BUILD}
cp yorick.ml ${TMP_BUILD}
cp travis_opam.ml ${TMP_BUILD}

cd ${TMP_BUILD}
sh .travis-ocaml.sh
export OPAMYES=1
eval $(opam config env)

# This could be removed with some OPAM variable plumbing into build commands
opam install ocamlfind

ocamlc.opt yorick.mli
ocamlfind ocamlc -c yorick.ml

ocamlfind ocamlc -o travis-opam -package unix -linkpkg yorick.cmo travis_opam.ml
cd -

${TMP_BUILD}/travis-opam
