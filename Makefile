# file locations

SOURCES=$(wildcard src/*.coffee) $(wildcard src/*/*.coffee)
TEST_SOURCES=$(wildcard test/bootstrap.coffee test/unit/*.coffee test/unit/*/*.coffee)
MAIN_SRC=src/lib.coffee

OUT_DIR=out
OUT_NAME=rtc

BUNDLE=$(OUT_DIR)/$(OUT_NAME).js
MIN_BUNDLE=$(OUT_DIR)/$(OUT_NAME).min.js
DEP_BUNDLE=$(OUT_DIR)/$(OUT_NAME).dep.js
MIN_DEP_BUNDLE=$(OUT_DIR)/$(OUT_NAME).dep.min.js
TEST_BUNDLE=$(OUT_DIR)/$(OUT_NAME).test.js

# phony stuff

all: compile min

compile: $(BUNDLE) $(DEP_BUNDLE)

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
	node_modules/.bin/browserify -c 'coffee -sc' --extension=".coffee" -s $(OUT_NAME) -d --no-bundle-external $(MAIN_SRC) -o $@

$(DEP_BUNDLE): $(SOURCES) init Makefile
	@mkdir -p $(OUT_DIR)
	node_modules/.bin/browserify -c 'coffee -sc' --extension=".coffee" -s $(OUT_NAME) -d $(MAIN_SRC) -o $@

$(TEST_BUNDLE): $(SOURCES) $(TEST_SOURCES) init Makefile
	node_modules/.bin/browserify -c 'coffee -sc' --extension=".coffee" -s $(OUT_NAME) -d $(MAIN_SRC) $(TEST_SOURCES) -o $@

%.min.js: %.js init Makefile
	node_modules/.bin/uglifyjs --compress --mangle -o $@ -- $<


.PHONY: all compile min clean doc test karma init example
