# SPDX-License-Identifier: 0BSD
# Self-contained Clang C++ modules support for GNU Make, using P1689 + jq.

ifndef CXX_MODULES_INCLUDED
CXX_MODULES_INCLUDED := 1
cxx_module_initial_default_goal := $(.DEFAULT_GOAL)

CXX ?= clang++
CXXFLAGS ?= -std=c++20
CXX_MODULE_FLAGS ?= $(CXXFLAGS)
CXX_MODULE_COMPILER ?= auto
CXX_MODULE_SCANNER ?= clang-scan-deps
CXX_MODULE_JQ ?= jq
CXX_MODULE_OUTPUT_DIR ?= build
# Retain the original name as a compatibility override. Setting either variable
# before including this fragment relocates all intermediate module artifacts.
CXX_MODULE_BUILD_DIR ?= $(CXX_MODULE_OUTPUT_DIR)
CXX_MODULE_BMI_DIR ?= $(CXX_MODULE_BUILD_DIR)/bmi
CXX_MODULE_OBJECT_DIR ?= $(CXX_MODULE_BUILD_DIR)/obj
CXX_MODULE_COMPDB ?= $(CXX_MODULE_BUILD_DIR)/compile_commands.json
CXX_MODULE_SCAN ?= $(CXX_MODULE_BUILD_DIR)/dependencies.p1689.json
CXX_MODULE_GRAPH ?= $(CXX_MODULE_BUILD_DIR)/modules.mk
CXX_MODULE_EXTENSIONS ?= cppm ixx mpp
CXX_MODULE_PATHS ?=
CXX_MODULE_EXTERNAL ?=
CXX_MODULE_EXTERNAL_REQUIRES ?=
CXX_MODULE_USE_STD ?= auto

ifeq ($(CXX_MODULE_COMPILER),auto)
cxx_module_compiler_macros := $(shell $(CXX) $(CXX_MODULE_FLAGS) -dM -E -x c++ /dev/null 2>/dev/null)
ifneq ($(findstring __clang__,$(cxx_module_compiler_macros)),)
CXX_MODULE_COMPILER := clang
else ifneq ($(findstring __GNUC__,$(cxx_module_compiler_macros)),)
CXX_MODULE_COMPILER := gcc
else
$(error cxx-modules.mk: cannot identify CXX='$(CXX)'; set CXX_MODULE_COMPILER to clang or gcc)
endif

endif

ifeq ($(CXX_MODULE_COMPILER),clang)
CXX_MODULE_BMI_EXTENSION ?= .pcm
else ifeq ($(CXX_MODULE_COMPILER),gcc)
CXX_MODULE_BMI_EXTENSION ?= .gcm
CXX_MODULE_FLAGS += -fmodules
CXX_MODULE_SCAN_DIR ?= $(CXX_MODULE_BUILD_DIR)/scan
else
$(error cxx-modules.mk: unsupported CXX_MODULE_COMPILER='$(CXX_MODULE_COMPILER)')
endif

ifeq ($(CXX_MODULE_COMPILER),clang)
CXX_MODULE_LIBCXX_MANIFEST := $(shell $(CXX) $(CXX_MODULE_FLAGS) -print-file-name=libc++.modules.json)
cxx_module_clang_resource_dir := $(shell $(CXX) $(CXX_MODULE_FLAGS) -print-resource-dir 2>/dev/null)
cxx_module_std_source_candidates := \
	$(abspath $(cxx_module_clang_resource_dir)/../../../share/libc++/v1/std.cppm) \
	$(abspath $(dir $(CXX_MODULE_LIBCXX_MANIFEST))/../share/libc++/v1/std.cppm) \
	/usr/local/share/libc++/v1/std.cppm \
	/usr/share/libc++/v1/std.cppm
CXX_MODULE_STD_SOURCE ?= $(firstword $(foreach source,$(cxx_module_std_source_candidates),$(wildcard $(source))))
CXX_MODULE_STD_COMPAT_SOURCE ?= $(wildcard $(dir $(CXX_MODULE_STD_SOURCE))std.compat.cppm)
CXX_MODULE_STD_BMI ?= $(CXX_MODULE_BMI_DIR)/std.pcm
CXX_MODULE_STD_OBJECT ?= $(CXX_MODULE_OBJECT_DIR)/std.o
ifneq ($(strip $(CXX_MODULE_STD_COMPAT_SOURCE)),)
CXX_MODULE_STD_COMPAT_BMI ?= $(CXX_MODULE_BMI_DIR)/std.compat.pcm
CXX_MODULE_STD_COMPAT_OBJECT ?= $(CXX_MODULE_OBJECT_DIR)/std.compat.o
endif
else
CXX_MODULE_STD_BUILD_DIR ?= $(CXX_MODULE_BUILD_DIR)/libstdc++
CXX_MODULE_STD_BMI ?= $(CXX_MODULE_STD_BUILD_DIR)/gcm.cache/std.gcm
CXX_MODULE_STD_COMPAT_BMI ?= $(CXX_MODULE_STD_BUILD_DIR)/gcm.cache/std.compat.gcm
CXX_MODULE_STD_OBJECT ?= $(CXX_MODULE_STD_BUILD_DIR)/std.o
CXX_MODULE_STD_COMPAT_OBJECT ?= $(CXX_MODULE_STD_BUILD_DIR)/std.compat.o
CXX_MODULE_MAPPER_ROOT ?= $(abspath $(CXX_MODULE_STD_BUILD_DIR)/gcm.cache)
endif

ifneq ($(filter 1 auto,$(CXX_MODULE_USE_STD)),)
CXX_MODULE_EXTERNAL += std=$(CXX_MODULE_STD_BMI)
ifeq ($(CXX_MODULE_COMPILER),gcc)
CXX_MODULE_EXTERNAL += std.compat=$(CXX_MODULE_STD_COMPAT_BMI)
CXX_MODULE_EXTERNAL_REQUIRES += std.compat=std
else ifneq ($(strip $(CXX_MODULE_STD_COMPAT_SOURCE)),)
CXX_MODULE_EXTERNAL += std.compat=$(CXX_MODULE_STD_COMPAT_BMI)
CXX_MODULE_EXTERNAL_REQUIRES += std.compat=std
endif
endif

cxx_module_walk = $(foreach e,$(wildcard $(1)/*),$(if $(wildcard $(e)/.),$(call cxx_module_walk,$(e)),$(e)))
cxx_module_discovered := $(sort $(filter $(foreach x,$(CXX_MODULE_EXTENSIONS),%.$(x)),$(foreach d,$(CXX_MODULE_PATHS),$(call cxx_module_walk,$(d)))))
CXX_MODULE_SOURCES := $(sort $(CXX_MODULE_SOURCES) $(cxx_module_discovered))
cxx_module_all_sources := $(sort $(CXX_MODULE_SOURCES) $(CXX_SOURCES))

ifeq ($(strip $(cxx_module_all_sources)),)
$(error cxx-modules.mk: configure CXX_MODULE_SOURCES, CXX_MODULE_PATHS, or CXX_SOURCES before including this file)
endif

cxx_module_object = $(CXX_MODULE_OBJECT_DIR)/$(basename $(patsubst ./%,%,$(1))).o
cxx_module_comma := ,
define cxx_module_compdb_entry
{"directory":"$(CURDIR)","command":"$(CXX) $(CXX_MODULE_FLAGS) -c $(1) -o $(call cxx_module_object,$(1))","file":"$(1)","output":"$(call cxx_module_object,$(1))"}
endef
cxx_module_compdb_entries = $(foreach s,$(cxx_module_all_sources),$(call cxx_module_compdb_entry,$(s)))
cxx_module_compdb_json = [$(subst } {,}$(cxx_module_comma) {,$(strip $(cxx_module_compdb_entries)))]

# Materialized beside the graph only while its recipe runs, keeping this file
# the sole distributable.
define cxx_module_jq_program
def bmi_name($$name):
  ($$name | gsub(":"; "@3A")) as $$encoded |
  "\($$bmi_dir)/\($$encoded)\($$bmi_extension)";

($$externals | split(" ") | map(select(length > 0) | split("=") |
  {(.[0]): (.[1:] | join("="))}) | add // {}) as $$external_bmis |
($$external_requires | split(" ") | map(select(length > 0) | split("=") |
  {(.[0]): (.[1:] | join("=") | split(",") | map(select(length > 0)))}) |
  add // {}) as $$external_requirements |
($$external_bmis | to_entries | map({key: .key, value: {
  bmi: .value, requires: ($$external_requirements[.key] // [])
}}) | from_entries) as $$external |
([.rules[] | . as $$rule | (.provides // [])[] |
  {key: .["logical-name"], value: {
    bmi: bmi_name(.["logical-name"]),
    requires: [($$rule.requires // [])[]["logical-name"]]
  }}] | from_entries) as $$local |
($$external + $$local) as $$providers |
($$compdb[0] | map({key: .output, value: .file}) | from_entries) as $$sources |

def provider($$name):
  $$providers[$$name] // error("no provider for imported module: \($$name)");

def closure($$names; $$seen):
  reduce $$names[] as $$name ({out: [], seen: $$seen};
    if .seen[$$name] then .
    else (provider($$name)) as $$p |
      .seen[$$name] = true |
      (closure($$p.requires; .seen)) as $$children |
      .out += [$$name] + $$children |
      reduce $$children[] as $$child (. ; .seen[$$child] = true)
    end) | .out;

def imports($$rule):
  [($$rule.requires // [])[]["logical-name"]] |
  closure(.; {}) | unique | map("\(.)=\(provider(.).bmi)") | join(" ");

def direct_bmis($$rule):
  [($$rule.requires // [])[]["logical-name"] | provider(.).bmi] | unique | join(" ");

def source($$rule):
  (($$rule.provides // [])[0]["source-path"] // $$sources[$$rule["primary-output"]])
  // error("no source for output: \($$rule["primary-output"])");

"# Generated from P1689 dependency facts. Do not edit.",
"CXX_MODULE_P1689_USES_STD := \([.rules[] | (.requires // [])[] | .["logical-name"] | select(. == "std" or . == "std.compat")] | length > 0 | if . then 1 else 0 end)",
"CXX_MODULE_BMIS := \([.rules[] | (.provides // [])[] | bmi_name(.["logical-name"])] | unique | join(" "))",
"CXX_MODULE_OBJECTS := \([.rules[]["primary-output"]] | unique | join(" "))",
"CXX_MODULE_OUTPUT_GROUPS := \([.rules[] | select((.provides // []) | length > 0) | bmi_name(.provides[0]["logical-name"]) + "=" + .["primary-output"]] | unique | join(" "))",
(.rules[] |
  . as $$rule |
  source($$rule) as $$source |
  imports($$rule) as $$imports |
  direct_bmis($$rule) as $$direct |
  (($$rule.provides // [])[0]["logical-name"] // null) as $$provided |
  (if $$provided then bmi_name($$provided) else "" end) as $$own_bmi |
  (if $$compiler == "clang" then $$own_bmi else "" end) as $$object_bmi_dep |
  (if $$provided then $$provided + "=" + $$own_bmi else "" end) as $$provide_map |
  (if $$provided then
    "\($$own_bmi): \($$source) \($$direct)\n" +
    "\($$own_bmi): private CXX_MODULE_SOURCE := \($$source)\n" +
    "\($$own_bmi): private CXX_MODULE_PROVIDES := \($$provided)=\($$own_bmi)\n" +
    "\($$own_bmi): private CXX_MODULE_IMPORTS := \($$imports)\n"
   else "" end) +
  "\($$rule["primary-output"]): \($$source) \($$direct) \($$object_bmi_dep)\n" +
  "\($$rule["primary-output"]): private CXX_MODULE_SOURCE := \($$source)\n" +
  "\($$rule["primary-output"]): private CXX_MODULE_PCM := \($$own_bmi)\n" +
  "\($$rule["primary-output"]): private CXX_MODULE_PROVIDES := \($$provide_map)\n" +
  "\($$rule["primary-output"]): private CXX_MODULE_IMPORTS := \($$imports)\n")
endef

cxx_module_project_makefile := $(firstword $(MAKEFILE_LIST))
cxx_module_adapter_makefile := $(lastword $(MAKEFILE_LIST))

ifeq ($(filter clean,$(MAKECMDGOALS)),)
-include $(CXX_MODULE_GRAPH)
endif

ifeq ($(CXX_MODULE_USE_STD),auto)
cxx_module_use_std := $(CXX_MODULE_P1689_USES_STD)
else
cxx_module_use_std := $(CXX_MODULE_USE_STD)
endif

$(CXX_MODULE_COMPDB): $(cxx_module_all_sources) $(cxx_module_project_makefile) $(cxx_module_adapter_makefile) | $(dir $(CXX_MODULE_COMPDB))
	@$(file >$@,$(cxx_module_compdb_json))

$(dir $(CXX_MODULE_COMPDB)):
	@mkdir -p $@

ifeq ($(CXX_MODULE_COMPILER),clang)
$(CXX_MODULE_SCAN): $(CXX_MODULE_COMPDB) $(cxx_module_all_sources)
	@mkdir -p $(dir $@)
	$(CXX_MODULE_SCANNER) -format=p1689 -resource-dir-recipe=invoke-compiler \
		-compilation-database=$(CXX_MODULE_COMPDB) -o $@
else
cxx_module_gcc_scan = $(CXX_MODULE_SCAN_DIR)/$(basename $(patsubst ./%,%,$(1))).p1689.json
CXX_MODULE_SCAN_OUTPUTS := $(foreach s,$(cxx_module_all_sources),$(call cxx_module_gcc_scan,$(s)))

define cxx_module_gcc_scan_rule
$(call cxx_module_gcc_scan,$(1)): $(1) $(cxx_module_adapter_makefile)
	@mkdir -p $$(dir $$@)
	$$(CXX) $$(CXX_MODULE_FLAGS) -MMD -MF $$@.d -MT $$@ \
		-fdeps-format=p1689r5 -fdeps-file=$$@ \
		-fdeps-target=$(call cxx_module_object,$(1)) \
		-E -x c++ $(1) -o /dev/null
endef
$(foreach s,$(cxx_module_all_sources),$(eval $(call cxx_module_gcc_scan_rule,$(s))))
-include $(addsuffix .d,$(CXX_MODULE_SCAN_OUTPUTS))

$(CXX_MODULE_SCAN): $(CXX_MODULE_SCAN_OUTPUTS)
	@mkdir -p $(dir $@)
	$(CXX_MODULE_JQ) -s '{version: 1, revision: 0, rules: [.[].rules[]]}' $^ > $@.tmp
	@mv $@.tmp $@
endif

$(CXX_MODULE_GRAPH): $(CXX_MODULE_SCAN) $(CXX_MODULE_COMPDB) $(cxx_module_adapter_makefile)
	@mkdir -p $(dir $@)
	@$(file >$@.jq,$(subst $$$$,$$,$(value cxx_module_jq_program)))
	$(CXX_MODULE_JQ) -r --slurpfile compdb $(CXX_MODULE_COMPDB) \
		--arg bmi_dir $(CXX_MODULE_BMI_DIR) \
		--arg bmi_extension $(CXX_MODULE_BMI_EXTENSION) \
		--arg compiler $(CXX_MODULE_COMPILER) \
		--arg externals '$(CXX_MODULE_EXTERNAL)' \
		--arg external_requires '$(CXX_MODULE_EXTERNAL_REQUIRES)' \
		-f $@.jq $(CXX_MODULE_SCAN) > $@.tmp
	@mv $@.tmp $@
	@rm -f $@.jq

ifeq ($(CXX_MODULE_COMPILER),clang)
$(CXX_MODULE_BMIS):
	@mkdir -p $(dir $@)
	$(CXX) $(CXX_MODULE_FLAGS) \
		$(foreach m,$(CXX_MODULE_IMPORTS),-fmodule-file=$(m)) \
		--precompile $(CXX_MODULE_SOURCE) -o $@

$(CXX_MODULE_OBJECTS):
	@mkdir -p $(dir $@)
	$(CXX) $(if $(CXX_MODULE_PCM),$(filter-out -stdlib=%,$(CXX_MODULE_FLAGS)),$(CXX_MODULE_FLAGS)) \
		$(foreach m,$(CXX_MODULE_IMPORTS),-fmodule-file=$(m)) \
		-c $(if $(CXX_MODULE_PCM),$(CXX_MODULE_PCM),$(CXX_MODULE_SOURCE)) -o $@
else
cxx_module_group_objects := $(foreach g,$(CXX_MODULE_OUTPUT_GROUPS),$(word 2,$(subst =, ,$(g))))
cxx_module_consumer_objects := $(filter-out $(cxx_module_group_objects),$(CXX_MODULE_OBJECTS))

define cxx_module_write_mapper
	@mkdir -p $(dir $(1))
	@: > $(1).mapper
	@$(if $(CXX_MODULE_MAPPER_ROOT),printf '$$root %s\n' $(CXX_MODULE_MAPPER_ROOT) >> $(1).mapper;)
	@$(foreach m,$(CXX_MODULE_PROVIDES),printf '%s %s\n' $(word 1,$(subst =, ,$(m))) $(abspath $(word 2,$(subst =, ,$(m)))) >> $(1).mapper;)
	@$(foreach m,$(CXX_MODULE_IMPORTS),printf '%s %s\n' $(word 1,$(subst =, ,$(m))) $(abspath $(word 2,$(subst =, ,$(m)))) >> $(1).mapper;)
endef

define cxx_module_gcc_group_rule
$(subst =, ,$(1)) &:
	$$(call cxx_module_write_mapper,$(word 2,$(subst =, ,$(1))))
	$$(CXX) $$(CXX_MODULE_FLAGS) -fmodule-mapper=$(word 2,$(subst =, ,$(1))).mapper \
		-c $$(CXX_MODULE_SOURCE) -o $(word 2,$(subst =, ,$(1)))
endef
$(foreach g,$(CXX_MODULE_OUTPUT_GROUPS),$(eval $(call cxx_module_gcc_group_rule,$(g))))

$(cxx_module_consumer_objects):
	$(call cxx_module_write_mapper,$@)
	$(CXX) $(CXX_MODULE_FLAGS) -fmodule-mapper=$@.mapper \
		-c $(CXX_MODULE_SOURCE) -o $@
endif

ifeq ($(cxx_module_use_std),1)
ifeq ($(CXX_MODULE_COMPILER),clang)
ifeq ($(strip $(CXX_MODULE_STD_SOURCE)),)
$(error cxx-modules.mk: cannot locate libc++'s std.cppm; set CXX_MODULE_STD_SOURCE explicitly)
endif
$(CXX_MODULE_STD_BMI): $(CXX_MODULE_STD_SOURCE)
	@mkdir -p $(dir $@)
	$(CXX) $(CXX_MODULE_FLAGS) -Wno-reserved-module-identifier --precompile $< -o $@

$(CXX_MODULE_STD_OBJECT): $(CXX_MODULE_STD_BMI)
	@mkdir -p $(dir $@)
	$(CXX) $(filter-out -stdlib=%,$(CXX_MODULE_FLAGS)) -c $< -o $@

CXX_MODULE_OBJECTS += $(CXX_MODULE_STD_OBJECT)
ifneq ($(strip $(CXX_MODULE_STD_COMPAT_SOURCE)),)
$(CXX_MODULE_STD_COMPAT_BMI): $(CXX_MODULE_STD_COMPAT_SOURCE) $(CXX_MODULE_STD_BMI)
	@mkdir -p $(dir $@)
	$(CXX) $(CXX_MODULE_FLAGS) -Wno-reserved-module-identifier \
		-fmodule-file=std=$(CXX_MODULE_STD_BMI) --precompile $< -o $@

$(CXX_MODULE_STD_COMPAT_OBJECT): $(CXX_MODULE_STD_COMPAT_BMI)
	@mkdir -p $(dir $@)
	$(CXX) $(filter-out -stdlib=%,$(CXX_MODULE_FLAGS)) \
		-fmodule-file=std=$(CXX_MODULE_STD_BMI) -c $< -o $@

CXX_MODULE_OBJECTS += $(CXX_MODULE_STD_COMPAT_OBJECT)
endif
else
$(CXX_MODULE_STD_BMI) $(CXX_MODULE_STD_COMPAT_BMI) $(CXX_MODULE_STD_OBJECT) $(CXX_MODULE_STD_COMPAT_OBJECT) &:
	@mkdir -p $(CXX_MODULE_STD_BUILD_DIR)
	cd $(CXX_MODULE_STD_BUILD_DIR) && $(CXX) $(CXX_MODULE_FLAGS) -c --compile-std-module

CXX_MODULE_OBJECTS += $(CXX_MODULE_STD_OBJECT) $(CXX_MODULE_STD_COMPAT_OBJECT)
endif
endif

# Including a library fragment must not make one of its internal artifacts the
# project's default goal. If the project had no default yet, the first target
# following this include will become it normally.
.DEFAULT_GOAL := $(cxx_module_initial_default_goal)

endif
