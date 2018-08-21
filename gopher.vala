using Gtk;

int main (string[] args) {
    Gtk.init (ref args);
    var builder = new Gtk.Builder.from_resource ("/rain-1/gopher.ui");
	builder.connect_signals (null);

	var main_window = builder.get_object ("main_window") as Window;
	var back_button = builder.get_object ("back_button") as Button;
	var forward_button = builder.get_object ("forward_button") as Button;
	var go_button = builder.get_object ("go_button") as Button;
	var url_entry = builder.get_object ("url_entry") as Entry;
	var text_view = builder.get_object ("text_view") as TextView;
	var spinner = builder.get_object ("spinner") as Spinner;
	
	if(args.length == 2) {
	    url_entry.text = args[1];
	}

	Engine engine = new Engine (main_window, url_entry, text_view, spinner);
	back_button.clicked.connect (() => {
			engine.back();
		});
    forward_button.clicked.connect (() => {
			engine.forward();
		});
	go_button.clicked.connect (() => {
			engine.gopher_load (url_entry.text, true);
		});
	url_entry.activate.connect (() => {
			engine.gopher_load (url_entry.text, true);
		});
	
    Gtk.main ();
    return 0;
}
