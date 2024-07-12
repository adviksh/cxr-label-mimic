# Navigation ------------------------------------------------------------------
DATA_DIR = raw
TEMP_DIR = temp


# Helpers --------------------------------------------------------------------
include makefile_helpers


# Targets --------------------------------------------------------------------
DIR_TARGETS = temp temp/sentences code/log code/log/temp

all: $(DIR_TARGETS)
all: mimic_cxr_reports.csv
all: code/log/02_find-problems.log


# Recipes ------------------------------------------------------------------------

$(DIR_TARGETS):
	mkdir -p $@


# ------------------------------------------------------------------------------
# Break reports into sections
# ------------------------------------------------------------------------------
mimic_cxr_reports.csv: code/01_remove-indication.R
	Rscript --vanilla --verbose $< > code/log/temp/$(call file_slug, $<).log 2>&1 && \
	mv -f code/log/temp/$(call file_slug, $<).log code/log/$(call file_slug, $<).log
	

# ------------------------------------------------------------------------------
# Extract sentences for each problem
# ------------------------------------------------------------------------------
code/log/02_find-problems.log: code/02_find-problems.py mimic_cxr_reports.csv
	python $< > code/log/temp/$(call file_slug, $<).log 2>&1 && \
	mv -f code/log/temp/$(call file_slug, $<).log code/log/$(call file_slug, $<).log


# ------------------------------------------------------------------------------
# CheXbert labelling
# ------------------------------------------------------------------------------
$(TEMP_DIR)/mimic-cxr-reports/findings_and_impression/labels/chexbert/%.csv: 02_label-chexbert.py $(TEMP_DIR)/mimic-cxr-reports/findings_and_impression/sentences/%.csv ../../models/chexbert.pth
	mkdir -p $(TEMP_DIR)/mimic-cxr-reports/findings_and_impression/labels/chexbert \
	&& python 02_label-chexbert.py -d $(TEMP_DIR)/mimic-cxr-reports/findings_and_impression/sentences/$*.csv -o $@ -c ../../models/chexbert.pth
	
$(TEMP_DIR)/mimic-cxr-reports/findings_and_impression/labels/chexbert.fst: 03_reconcile-chexbert.R $(LABELS_CHEXBERT)
	$(call r,$<)


# ------------------------------------------------------------------------------
# Sentence Embeddings
# ------------------------------------------------------------------------------
	
	
# ------------------------------------------------------------------------------
# Flag Indications
# ------------------------------------------------------------------------------
