# file locations

SOURCES=$(shell find src -iname '*.ts')
TEST_SOURCES=$(shell find src -iname '*.ts')
MAIN_SRC=src/index.ts

OUT_DIR=out
OUT_NAME=rtc

BUNDLE=$(OUT_DIR)/$(OUT_NAME).js
MIN_BUNDLE=$(OUT_DIR)/$(OUT_NAME).min.js
DEP_BUNDLE=$(OUT_DIR)/$(OUT_NAME).dep.js
MIN_DEP_BUNDLE=$(OUT_DIR)/$(OUT_NAME).dep.min.js
TEST_BUNDLE=$(OUT_DIR)/$(OUT_NAME).test.js

# phony stuff

all: bundle min

bundle: $(BUNDLE) $(DEP_BUNDLE)

min: $(MIN_BUNDLE) $(MIN_DEP_BUNDLE)

init: node_modules

watch:
	while inotifywait -e close_write -r src ; do sleep 1; make; echo ; done

# actual work

node_modules: package.json
	npm install
	touch node_modules

clean:
	rm -r out doc

doc: init
	./node_modules/.bin/yuidoc --syntaxtype coffee -e .coffee -o doc src --themedir yuidoc-theme

test: init
	npm test

example: compile
	node example/serve.js

karma: init $(TEST_BUNDLE)
	node_modules/.bin/karma start karma.conf.js

$(BUNDLE): $(SOURCES) init Makefile
	@mkdir -p $(OUT_DIR)
	node_modules/.bin/browserify --extension .ts -p tsify -t [ babelify --extensions .ts ] -s $(OUT_NAME) -d --no-bundle-external $(MAIN_SRC) -o $@

$(DEP_BUNDLE): $(SOURCES) init Makefile
	@mkdir -p $(OUT_DIR)
	node_modules/.bin/browserify --extension .ts -p tsify -t [ babelify --extensions .ts ] -s $(OUT_NAME) -d $(MAIN_SRC) -o $@

$(TEST_BUNDLE): $(SOURCES) $(TEST_SOURCES) init Makefile
	node_modules/.bin/browserify --extension .ts -p tsify -t [ babelify --extensions .ts ] -s $(OUT_NAME) -d $(MAIN_SRC) $(TEST_SOURCES) -o $@

%.min.js: %.js init Makefile
	node_modules/.bin/uglifyjs --compress --mangle -o $@ -- $<


compile: $(SOURCES) node_modules Makefile
	@mkdir -p dist
	node_modules/.bin/tsc --declaration --outDir dist/js/
	node_modules/.bin/babel --out-dir dist/ejs/ dist/js
	node_modules/.bin/babel --plugins "@babel/plugin-transform-modules-commonjs" --out-dir dist/cjs/ dist/ejs

pack: compile
	npm pack

publish: pack
	npm publish

.PHONY: all compile pack min clean doc test karma init example
