#
# Theldus's blog
# This is free and unencumbered software released into the public domain.
#

# Directories
POST_DIR = website/posts
SRC_DIR  = src_posts

MACROS = inc/header.inc inc/footer.inc inc/macros.inc inc/config.inc

# Manually specified posts (without extensions)
POSTS = slackware15-on-a-pentium-133 \
        helping-your-old-pc-build-faster-with-your-mobile \
        the-only-proper-way-to-debug-16bit-code \
        beware-with-geekbench-v6-results \
        ricing-my-tux-boot-logo

# Convert source filenames to their target paths
POSTS_HTML     = $(POSTS:%=$(POST_DIR)/%/index.html)
NON_POSTS_HTML = website/index.html \
				 website/404.html \
				 website/about/index.html

# Scripts
PREPROCESS  = $(CURDIR)/proc.py preprocess
POSTPROCESS = $(CURDIR)/proc.py postprocess
GEN_INDEX  = $(CURDIR)/gen_index.sh

# Pretty print
Q := @
ifeq ($(V), 1)
	Q :=
endif

.PHONY: all clean
all: $(POSTS_HTML) website/index.html $(NON_POSTS_HTML)

# Pattern rule to generate HTML from NASM
$(POST_DIR)/%/index.html: $(SRC_DIR)/%.asm proc.py $(MACROS)
	@echo "Building post $@"
	$(Q)mkdir -p $(dir $@)
	@echo "  -> Pre-preprocessing $<"
	$(Q)SRC_DIR=$(SRC_DIR) $(PREPROCESS) $< $@
	@echo "  -> NASM preprocessing..."
	$(Q)nasm -I inc -E -w-pp-open-string $@ > $@.tmp
	@echo "  -> Post-processing..."
	$(Q)$(POSTPROCESS) $(@).tmp > $@
	$(Q)rm $@.tmp

$(SRC_DIR)/index.asm: gen_index.sh $(POSTS_HTML)
	@echo "Generating $@"
	$(Q)$(GEN_INDEX) $(POSTS)

website/index.html: $(SRC_DIR)/index.asm proc.py $(MACROS)
	@echo "Building $@"
	$(Q)SRC_DIR=$(SRC_DIR) $(PREPROCESS) $< $@
	$(Q)nasm -I inc -E -w-pp-open-string $@ > $@.tmp
	@echo "  -> Post-processing..."
	$(Q)$(POSTPROCESS) $(@).tmp > $@
	$(Q)rm $@.tmp

website/404.html: $(SRC_DIR)/404.asm proc.py $(MACROS)
	@echo "Building $@"
	$(Q)SRC_DIR=$(SRC_DIR) $(PREPROCESS) $< $@
	$(Q)nasm -I inc -E -w-pp-open-string $@ > $@.tmp
	@echo "  -> Post-processing..."
	$(Q)$(POSTPROCESS) $(@).tmp > $@
	$(Q)rm $@.tmp

website/about/index.html: $(SRC_DIR)/about.asm proc.py $(MACROS)
	@echo "Building $@"
	$(Q)mkdir -p $(dir $@)
	$(Q)SRC_DIR=$(SRC_DIR) $(PREPROCESS) $< $@
	$(Q)nasm -I inc -E -w-pp-open-string $@ > $@.tmp
	@echo "  -> Post-processing..."
	$(Q)$(POSTPROCESS) $(@).tmp > $@
	$(Q)rm $@.tmp

# Clean up generated files
clean:
	rm -rf $(POSTS:%=$(POST_DIR)/%)
	rm -rf website/about
	rm -f  website/index.html
	rm -f  website/404.html
	rm -f  src_posts/index.asm
