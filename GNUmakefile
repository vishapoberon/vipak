DEPEND = github.com/norayr/unixFileSystem github.com/norayr/strutils github.com/norayr/base64 github.com/norayr/dbg github.com/norayr/Internet github.com/norayr/http github.com/norayr/mbedtls github.com/norayr/lists github.com/norayr/opts github.com/norayr/skprLogger codeberg.org/sts-q/vishaps-ssqJson

VOC = voc
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir_path := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
$(info $$mkfile_path is [${mkfile_path}])
$(info $$mkfile_dir_path is [${mkfile_dir_path}])
ifndef BUILD
BUILD="build"
endif
build_dir_path := $(mkfile_dir_path)/$(BUILD)
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
BLD := $(mkfile_dir_path)/build
DPD  =  deps
ifndef DPS
DPS := $(mkfile_dir_path)/$(DPD)
endif
all: get_deps build_deps buildThis
#all:  build_deps buildThis

get_deps:
	@echo "getting deps"
	@for i in $(DEPEND); do \
	if [ -d "$(DPS)/$${i}" ]; then \
	cd "$(DPS)/$${i}"; \
	git pull; \
	cd - ;    \
	else \
	mkdir -p "$(DPS)/$${i}"; \
	cd "$(DPS)/$${i}"; \
	cd .. ; \
	git clone "https://$${i}"; \
	cd - ; \
	fi; \
	done
	@echo "________________________________________"

build_deps:
	@echo "building deps"
	mkdir -p $(BLD)
	cd $(BLD); \
	for i in $(DEPEND); do \
	if [ -f "$(DPS)/$${i}/GNUmakefile" ]; then \
		make -f "$(DPS)/$${i}/GNUmakefile" BUILD=$(BLD); \
	else \
		make -f "$(DPS)/$${i}/Makefile" BUILD=$(BLD); \
	fi; \
	done
	@echo "________________________________________"

buildThis:
	@echo "building vipak"
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkTools.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkSettings.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/unix/vpkTime.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkLogger.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/unix/vpkEnv.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/unix/vpkGit.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkStorage.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkConf.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkdepTree.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkMD5Checker.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkHttp.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkHttps.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkSyncer.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkDot.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkResolver.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkJsonDepRetriever.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkInstaller.Mod
	cd $(BUILD) && $(VOC) -s $(mkfile_dir_path)/src/vpkLocalBuilder.Mod
	cd $(BUILD) && $(VOC) $(mkfile_dir_path)/src/vipak.Mod -cm
	cd $(BUILD) && gcc -o vipak *.o -static -L/opt/voc/lib -lvoc-O2 /opt/voc/lib/libvoc-O2.a -L. -lmbedtls -lmbedcrypto -lmbedx509 libmbedcrypto.a libmbedtls.a libmbedx509.a
	@echo "________________________________________"

tests:
	#cd $(BUILD) && $(VOC) $(mkfile_dir_path)/test/testList.Mod -m
	#build/testList

clean:
	if [ -d "$(BUILD)" ]; then rm -rf $(BLD); fi
