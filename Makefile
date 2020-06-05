# file locations

SOURCES=$(shell find src -iname '*.ts')
TEST_SOURCES=$(shell find src -iname '*.ts')
MAIN_SRC=src/index.ts

OUT_DIR=out
OUT_NAME=rtc

BUNDLE=dist/bundle/$(OUT_NAME).js
MIN_BUNDLE=dist/bundle/$(OUT_NAME).min.js
DEP_BUNDLE=dist/bundle/$(OUT_NAME).dep.js
MIN_DEP_BUNDLE=dist/bundle/$(OUT_NAME).dep.min.js

# phony stuff

all: bundle min

bundle: $(BUNDLE) $(DEP_BUNDLE)

min: $(MIN_BUNDLE) $(MIN_DEP_BUNDLE)

watch:
	while inotifywait -e close_write -r src ; do sleep 1; make; echo ; done

# actual work

node_modules: package.json
	npm install
	touch node_modules

clean:
	rm -r out doc

doc: node_modules
	./node_modules/.bin/yuidoc --syntaxtype coffee -e .coffee -o doc src --themedir yuidoc-theme

test: node_modules
	npm test

example: compile
	node example/serve.js

karma: node_modules
	node_modules/.bin/karma start karma.conf.js

$(BUNDLE): $(SOURCES) node_modules Makefile
	@mkdir -p `dirname $@`
	node_modules/.bin/browserify --extension .ts -p tsify -t [ babelify --extensions .ts ] -s $(OUT_NAME) -d --no-bundle-external $(MAIN_SRC) -o $@

$(DEP_BUNDLE): $(SOURCES) node_modules Makefile
	@mkdir -p `dirname $@`
	node_modules/.bin/browserify --extension .ts -p tsify -t [ babelify --extensions .ts ] -s $(OUT_NAME) -d $(MAIN_SRC) -o $@

%.min.js: %.js node_modules Makefile
	node_modules/.bin/terser --compress --mangle -o $@ -- $<


compile: $(SOURCES) node_modules Makefile min
	@mkdir -p dist
	node_modules/.bin/tsc --declaration --outDir dist/js/
	node_modules/.bin/babel --out-dir dist/ejs/ dist/js
	node_modules/.bin/babel --plugins "@babel/plugin-transform-modules-commonjs" --out-dir dist/cjs/ dist/ejs

pack: compile
	npm pack

publish: pack
	npm publish

.PHONY: all compile pack min clean doc test karma init example
