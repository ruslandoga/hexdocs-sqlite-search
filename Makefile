CC = gcc
CFLAGS = -shared -fPIC -Wall -Wextra -O2
LDFLAGS = -lsqlite3
SRC = c_src/hexdocs.c
OUT_PREFIX = priv/hexdocs
EXT = so

# Detect the host operating system
ifeq ($(shell uname -s), Darwin)
  EXT = dylib
endif

build: $(SRC)
	$(CC) $(CFLAGS) -o $(OUT_PREFIX).$(EXT) $(SRC) $(LDFLAGS)

.PHONY: clean

clean:
	rm -f $(OUT_PREFIX)-*.$(EXT)
