CC := gcc
CFLAGS := -Wall
SRC := compiler_hw1.l
TARGET := myscanner
v := 0

all: ${TARGET}

${TARGET}: lex.yy.c
	@${CC} ${CFLAGS} -o $@ $<

lex.yy.c: ${SRC}
	@lex ${SRC}

judge: all
	@python3 judge/judge.py -v ${v} || printf "or \`make judge v=1\`"

clean:
	@rm -f ${TARGET} lex.*
