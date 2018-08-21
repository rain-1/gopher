all: gopher

clean:
	rm -f gopher
	rm -f gopher.vala.c resources.c

resources.c: resources.xml
	glib-compile-resources --generate-source --target resources.c resources.xml

gopher: gopher.vala engine.vala resources.c
	valac --thread --pkg glib-2.0 --pkg gtk+-3.0 --pkg gdk-3.0 --gresources=resources.xml gopher.vala engine.vala resources.c
