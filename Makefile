all: gopher

clean:
	rm -f gopher
	rm -f gopher.vala.c

gopher: gopher.vala engine.vala
	valac --thread --pkg glib-2.0 --pkg gtk+-3.0 --pkg gdk-3.0 gopher.vala engine.vala
