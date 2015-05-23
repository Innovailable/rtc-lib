# file locations

SOURCES=$(wildcard src/*.coffee)
MAIN_SRC=src/lib.coffee

OUT_DIR=out
OUT_NAME=rtc

BUNDLE=$(OUT_DIR)/$(OUT_NAME).js
MIN_BUNDLE=$(OUT_DIR)/$(OUT_NAME).min.js
DEP_BUNDLE=$(OUT_DIR)/$(OUT_NAME).dep.js
MIN_DEP_BUNDLE=$(OUT_DIR)/$(OUT_NAME).dep.min.js

# phony stuff

all: compile min

compile: $(BUNDLE) $(DEP_BUNDLE)

min: $(MIN_BUNDLE) $(MIN_DEP_BUNDLE)

# actual work

clean:
	rm -r out

$(BUNDLE): $(SOURCES) Makefile
	@mkdir -p $(OUT_DIR)
	browserify -c 'coffee -sc' --extension=".coffee" -s $(OUT_NAME) -d --no-bundle-external $(MAIN_SRC) -o $@

$(DEP_BUNDLE): $(SOURCES) Makefile
	@mkdir -p $(OUT_DIR)
	browserify -c 'coffee -sc' --extension=".coffee" -s $(OUT_NAME) -d $(MAIN_SRC) -o $@

%.min.js: %.js Makefile
	uglifyjs --compress --mangle -o $@ -- $<


.PHONY: all compile min clean

