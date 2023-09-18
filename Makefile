SRC = c_src/hexdocs.c
HEADERS = deps/exqlite/c_src/sqlite3ext.h  
CFLAGS = -Wall -Wextra -O2 -Ideps/exqlite/c_src

PREFIX = $(MIX_APP_PATH)/priv
BUILD  = $(MIX_APP_PATH)/obj
LIB_NAME = $(PREFIX)/hexdocs.so
ARCHIVE_NAME = $(PREFIX)/hexdocs.a

OBJ = $(SRC:c_src/%.c=$(BUILD)/%.o)

ifeq ($(KERNEL_NAME), Linux)
	CFLAGS += -fPIC -fvisibility=hidden
	LDFLAGS += -fPIC -shared
endif
ifeq ($(KERNEL_NAME), Darwin)
	CFLAGS += -fPIC
	LDFLAGS += -dynamiclib -undefined dynamic_lookup
endif
ifeq ($(KERNEL_NAME), $(filter $(KERNEL_NAME),OpenBSD FreeBSD NetBSD))
	CFLAGS += -fPIC
	LDFLAGS += -fPIC -shared
endif

all: $(PREFIX) $(BUILD) $(LIB_NAME)

$(BUILD)/%.o: c_src/%.c
	@echo " CC $(notdir $@)"
	$(CC) -c $(ERL_CFLAGS) $(CFLAGS) -o $@ $<

$(LIB_NAME): $(OBJ)
	@echo " LD $(notdir $@)"
	$(CC) -o $@ $^ $(LDFLAGS)

$(ARCHIVE_NAME): $(OBJ)
	@echo " AR $(notdir $@)"
	$(AR) -rv $@ $^

$(PREFIX) $(BUILD):
	mkdir -p $@

clean:
	$(RM) $(LIB_NAME) $(ARCHIVE_NAME) $(OBJ)

.PHONY: all clean

# Don't echo commands unless the caller exports "V=1"
${V}.SILENT:
