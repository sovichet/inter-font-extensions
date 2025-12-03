# SOURCES=$(shell python3 scripts/read-config.py --sources )
# FAMILY=$(shell python3 scripts/read-config.py --family )
FAMILY:=Inter Southeast Asian Scripts
DRAWBOT_SCRIPTS=$(shell ls documentation/*.py)
DRAWBOT_OUTPUT=$(shell ls documentation/*.py | sed 's/\.py/.png/g')
INTER_ARCHIVE:=https://github.com/rsms/inter/archive/refs/tags/v4.1.zip
PYTHONPATH=./recipeproviders
VENV = . venv/bin/activate

help:
	@echo "###"
	@echo "# Build targets for $(FAMILY)"
	@echo "###"
	@echo
	@echo "  make build:  Builds the fonts and places them in the fonts/ directory"
	@echo "  make build-only-var:  Builds only variable fonts and places them in the fonts/ directory"
	@echo "  make test:   Tests the fonts with fontbakery"
	@echo "  make proof:  Creates HTML proof documents in the proof/ directory"
	@echo

inter:
	wget $(INTER_ARCHIVE) -O ./inter.zip
	unzip ./inter.zip
	mv inter-master inter
	rm inter.zip

inter/build/ufo-editable:
	cp Makefile-inter inter
	cd inter && make editable-ufos --file=Makefile-inter && rm Makefile-inter

build: inter build.stamp

venv: venv/touchfile

venv-test: venv-test/touchfile

# customize: venv
# 	. venv/bin/activate; python3 scripts/customize.py

build.stamp: venv sources/config-*.yaml inter/build/ufo-editable sources/master_ufo
	rm -rf fonts
	for config in sources/config-*.yaml; do \
		$(VENV); export PYTHONPATH=./recipeproviders; gftools builder $$config; \
	done
#	rm -rf sources/master_ufo
	touch build.stamp

.PHONY: build-%
build-%: venv sources/master_ufo sources/config-*.yaml inter/build/ufo-editable
	lang=$*; \
	echo "Building for script: $$lang"; \
	if [ "$$lang" = "khmer" ] || [ "$$lang" == "thai" ] || [ "$$lang" == "myanmar" ]; then \
		for config in sources/config-$$lang-*.yaml sources/config-$$lang.yaml; do \
			if [ -e "$$config" ]; then \
				$(VENV); export PYTHONPATH=./recipeproviders; gftools builder "$$config"; \
			fi \
		done \
	else \
		echo "Unknown script: $$lang"; \
	fi


.PHONY: build-only-var
build-only-var: inter build-only-var.stamp

build-only-var.stamp: venv sources/config-*.yaml inter/build/ufo-editable sources/master_ufo
	rm -rf fonts
	$(VENV); python scripts/config-for-vf.py
	for config in sources/vf-config-*.yaml; do \
		$(VENV); export PYTHONPATH=./recipeproviders; gftools builder $$config; \
	done
	rm -rf sources/vf-config-*.yaml
	touch build.stamp
	touch build-only-var.stamp

sources/master_ufo:
	@mkdir -p $@
	cp -r features $@/
	for gpkg in sources/**/*.glyphspackage; do \
		$(VENV); fontmake -o ufo -g $$gpkg --master-dir sources/master_ufo; \
	done
	for master in sources/master_ufo/*.ufo; do \
		$(VENV); python scripts/process-merge.py $$master; \
	done

venv/touchfile: requirements.txt
	test -d venv || python3 -m venv venv
	$(VENV); pip install -Ur requirements.txt
	touch venv/touchfile

venv-test/touchfile: requirements-test.txt
	test -d venv-test || python3 -m venv venv-test
	. venv-test/bin/activate; pip install -Ur requirements-test.txt
	touch venv-test/touchfile

test: venv-test build.stamp
	for script_dir in $$(ls -d fonts/**); do \
		SCRIPT=$$(basename $$script_dir); \
		TOCHECK=$$(find $$script_dir/variable -type f 2>/dev/null); if [ -z "$$TOCHECK" ]; then TOCHECK=$$(find $$script_dir/ttf -type f 2>/dev/null); fi ; . venv-test/bin/activate; mkdir -p out/ out/fontbakery; fontbakery check-googlefonts -l WARN --full-lists --succinct -x check/article/images -x family/consistent_family_name --badges out/badges --html out/fontbakery/fontbakery-$$SCRIPT-report.html --ghmarkdown out/fontbakery/fontbakery-$$SCRIPT-report.md $$TOCHECK  || echo '::warning file=sources/config.yaml,title=Fontbakery failures::The fontbakery QA check reported errors in your font. Please check the generated report.'; \
	done

proof: venv build.stamp
	for script_dir in $$(ls -d fonts/**); do \
		SCRIPT=$$(basename $$script_dir); \
		TOCHECK=$$(find $$script_dir/variable -type f 2>/dev/null); if [ -z "$$TOCHECK" ]; then TOCHECK=$$(find $$script_dir/ttf -type f 2>/dev/null); fi ; $(VENV); mkdir -p out/ out/proof/$$SCRIPT; diffenator2 proof $$TOCHECK -o out/proof/$$SCRIPT; \
	done

images: venv $(DRAWBOT_OUTPUT)

%.png: %.py build.stamp
	$(VENV); python3 $< --output $@

clean:
	rm -rf venv
	rm -rf venv-test
	rm -rf sources/master_ufo
	rm -rf inter/build/ufo-editable
	find . -name "*.pyc" -delete
	cd inter && make clean

# update-project-template:
# 	npx update-template https://github.com/googlefonts/googlefonts-project-template/

# update: venv venv-test
# 	venv/bin/pip install --upgrade pip-tools
# 	# See https://pip-tools.readthedocs.io/en/latest/#a-note-on-resolvers for
# 	# the `--resolver` flag below.
# 	venv/bin/pip-compile --upgrade --verbose --resolver=backtracking requirements.in
# 	venv/bin/pip-sync requirements.txt

# 	venv-test/bin/pip install --upgrade pip-tools
# 	venv-test/bin/pip-compile --upgrade --verbose --resolver=backtracking requirements-test.in
# 	venv-test/bin/pip-sync requirements-test.txt

# 	git commit -m "Update requirements" requirements.txt requirements-test.txt
# 	git push
