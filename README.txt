A simple gopher client in vala
==============================

Thank you to Bob131 for teaching me the correct way to do the threading!

Thank you to chrisawi for helping me correct some gtk outside the main thread mistakes, and suggesting several code improvements as well as the "\n\r" instead of "\r\n" bug.

## How to build

You need valac the vala compiler and gtk library and the gtk dev package (on debian it's libgtk-3-dev)

then just run 'make'

## How to make gopher links open in this client

* put the `xdg-open` script in ~/bin
* add ~/bin to PATH such that it overrides your system `xdg-open`
* `export GOPHER=` point to this gopher client
