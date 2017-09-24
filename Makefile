REPO=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
REPO_GOPATH=$(REPO)/go
MINIFY=$(REPO_GOPATH)/bin/minify
JS=$(REPO)/contrib/static/nntpchan.js
CONTRIB_JS=$(REPO)/contrib/js/contrib
LOCAL_JS=$(REPO)/contrib/js/nntpchan
VENDOR_JS=$(REPO)/contrib/js/vendor
SRND_DIR=$(REPO)/contrib/backends/srndv2
NNTPCHAND_DIR=$(REPO)/contrib/backends/nntpchand
NNTPCHAN_DAEMON_DIR=$(REPO)/contrib/backends/nntpchan-daemon
SRND=$(REPO)/srndv2
GOROOT=$(shell go env GOROOT)
GO=$(GOROOT)/bin/go

all: clean build

build: js srnd

js: $(JS)

srnd: $(SRND)

$(MINIFY):
	GOPATH=$(REPO_GOPATH) go get -v github.com/tdewolff/minify/cmd/minify

js-deps: $(MINIFY)

$(JS): js-deps
	rm -f $(JS)
	for f in $(CONTRIB_JS)/*.js ; do $(MINIFY) --mime=text/javascript >> $(JS) < $$f ; done
	$(MINIFY) --mime=text/javascript >> $(JS) < $(REPO)/contrib/js/entry.js
	for f in $(LOCAL_JS)/*.js ; do $(MINIFY) --mime=text/javascript >> $(JS) < $$f ; done
	for f in $(VENDOR_JS)/*.js ; do $(MINIFY) --mime=text/javascript >> $(JS) < $$f ; done


$(SRND):
	GOROOT=$(GOROOT) $(MAKE) -C $(SRND_DIR)
	cp $(SRND_DIR)/srndv2 $(SRND)

test: test-go test-native

test-go:
	GOROOT=$(GOROOT) $(MAKE) -C $(SRND_DIR) test
	GOROOT=$(GOROOT) $(MAKE) -C $(NNTPCHAND_DIR) test

test-native:
	GOROOT=$(GOROOT) $(MAKE) -C $(NNTPCHAN_DAEMON_DIR) test

clean:
	rm -f $(SRND) $(JS)
	GOROOT=$(GOROOT) $(MAKE) -C $(SRND_DIR) clean

distclean: clean
	rm -rf $(REPO_GOPATH)
