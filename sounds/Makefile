
SOUNDS = alarm move warning pass ring connect user_unknown gamestart resign outoftime info

%: %.wav Makefile
	sox -twav $< -tau -r8000 -c1 -U -b $@ polyphase || sox -twav $< -tau -r8000 -c1 -U -b $@

all: $(SOUNDS)
