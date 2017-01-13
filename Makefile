all: gopher

clean:
	rm -f gopher
	rm -f gopher.vala.c

gopher: gopher.vala engine.vala
	valac --thread --pkg gtk+-3.0 --pkg glib-2.0 gopher.vala engine.vala
