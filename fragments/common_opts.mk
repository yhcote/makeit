# a list of extra files to clean augmented by each module.conf
CLEANFILES :=

# general build-wide compile options
CFLAGS := -Wall -Wstrict-prototypes -Wextra -Wunused -Wno-sign-compare
CFLAGS += -Wno-missing-braces -Wno-parentheses -Wno-unknown-pragmas
CFLAGS += -Wno-switch -Wno-comment -Wno-missing-field-initializers
CFLAGS += -Werror -fno-common -Wuninitialized
CFLAGS += -pipe -fmessage-length=0

CPPFLAGS := -Icontrib/plan9/include

LDFLAGS := -static -L$(BUILDDIR)/contrib/plan9/src/libbio
LDFLAGS += -L$(BUILDDIR)/contrib/plan9/src/lib9 -lbio -l9
