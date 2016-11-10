# We need to rebootstrap soong if SOONG_OUT_DIR or the reverse path from
# SOONG_OUT_DIR to TOP changes
SOONG_NEEDS_REBOOTSTRAP :=
ifneq ($(wildcard $(SOONG_BOOTSTRAP)),)
  ifneq ($(SOONG_OUT_DIR),$(strip $(shell source $(SOONG_BOOTSTRAP); echo $$BUILDDIR)))
    SOONG_NEEDS_REBOOTSTRAP := FORCE
    $(warning soong_out_dir changed)
  endif
  ifneq ($(strip $(shell build/soong/scripts/reverse_path.py $(SOONG_OUT_DIR))),$(strip $(shell source $(SOONG_BOOTSTRAP); echo $$SRCDIR_FROM_BUILDDIR)))
    SOONG_NEEDS_REBOOTSTRAP := FORCE
    $(warning reverse path changed)
  endif
endif

# Bootstrap soong.
$(SOONG_BOOTSTRAP): bootstrap.bash $(SOONG_NEEDS_REBOOTSTRAP)
	$(hide) mkdir -p $(dir $@)
	$(hide) BUILDDIR=$(SOONG_OUT_DIR) ./bootstrap.bash

# Tell soong that it is embedded in make
$(SOONG_IN_MAKE):
	$(hide) mkdir -p $(dir $@)
	$(hide) touch $@

# Run Soong, this implicitly create an Android.mk listing all soong outputs as
# prebuilts.
.PHONY: run_soong
run_soong: $(SOONG_BOOTSTRAP) $(SOONG_VARIABLES) $(SOONG_IN_MAKE) FORCE
	$(hide) SKIP_NINJA=true $(SOONG)
