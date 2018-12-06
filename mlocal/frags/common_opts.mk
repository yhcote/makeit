#
# common build options for C projects

# a list of extra files to clean augmented by each module (*.mconf) file
CLEANFILES :=

# general build-wide compile options
AFLAGS := -g

CFLAGS := -ansi -Wall -Wstrict-prototypes -Wextra -Wunused -Werror
CGLAGS += -Wuninitialized -Wshadow -Wpointer-arith -Wbad-function-cast
CFLAGS += -Wwrite-strings -Woverlength-strings -Wstrict-prototypes
CFLAGS += -Wunreachable-code -Wframe-larger-than=2047 -Wno-discarded-qualifiers
CFLAGS += -Wfatal-errors -pipe -fmessage-length=0 -fplan9-extensions

CPPFLAGS += -I$(BUILDDIR)
