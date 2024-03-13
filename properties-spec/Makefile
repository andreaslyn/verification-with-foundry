
OUTDIR=.
NAME=properties-spec
TEX=$(NAME).tex
PDF="$(OUTDIR)"/"$(NAME)".pdf

LATEXMK_COMMON_OPTIONS=-output-directory=$(OUTDIR) -pdf

all: $(PDF)

$(PDF): $(TEX)
	latexmk $(LATEXMK_COMMON_OPTIONS) $(NAME)

clean:
	latexmk $(LATEXMK_COMMON_OPTIONS) -c

distclean:
	latexmk $(LATEXMK_COMMON_OPTIONS) -C
