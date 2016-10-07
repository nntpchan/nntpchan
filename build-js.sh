#!/usr/bin/env bash
root=$(readlink -e $(dirname $0))
set -e
if [ "x" == "x$root" ] ; then
    root=$PWD/${0##*}
fi
cd $root

if [ -z "$GOPATH" ]; then
	export GOPATH=$root/go
	mkdir -p $GOPATH
fi

if [ ! -f $GOPATH/bin/minify ]; then
  echo "set up minifiy"  
	go get -v github.com/tdewolff/minify/cmd/minify
fi

outfile=$PWD/contrib/static/nntpchan.js

lint() {
    if [ "x$(which jslint)" == "x" ] ; then
        # no jslint
        true
    else
        echo "jslint: $1"
        jslint --browser $1
    fi
}

mini() {
    echo "minify $1"
    echo "" >> $2
    echo "/* local file: $1 */" >> $2
    $GOPATH/bin/minify --mime=text/javascript >> $2 < $1
}

# do linting too
if [ "x$1" == "xlint" ] ; then
    echo "linting..."
    for f in ./contrib/js/*.js ; do
        lint $f
    done
fi

echo -e "//For source code and license information please check https://github.com/majestrate/nntpchan \n" > $outfile

if [ -e ./contrib/js/contrib/*.js ] ; then
    for f in ./contrib/js/contrib/*.js ; do
        mini $f $outfile
    done
fi
    
mini ./contrib/js/entry.js $outfile

# local js
for f in ./contrib/js/nntpchan/*.js ; do
  mini $f $outfile
done

# vendor js
for f in ./contrib/js/vendor/*.js ; do
  mini $f $outfile
done

echo "ok"
