LDC ?= ldc2

.PHONY: build
build:
	$(LDC) -O app.d

.PHONY: run
run: build
	./app

.PHONY: clean
clean:
	rm app *.o
