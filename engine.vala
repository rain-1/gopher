using Gtk;
using GLib;

enum LinkType {
	GOPHE,
	HYPER,
}

class Engine : Object {
	Window main_window;
    Entry url_entry;
	TextView text_view;
	Spinner spinner;

	List<string> history;
	List<string> future;

	Regex gopher_url_regex;
	Regex gopher_line_regex;

	public Engine (Window main_window, Entry url_entry, TextView text_view, Spinner spinner) {
		this.main_window = main_window;
		this.url_entry = url_entry;
		this.text_view = text_view;
		this.spinner = spinner;

	    history = new List<string> ();
		future = new List<string> ();
		
		fix_cursor ();

		gopher_url_regex = /^(gopher:\/\/)?(?<host>[^\/:]*)(:(?<port>[0-9]+))?(\/((?<gophertype>.))(?<selector>[^:]*))?\/?$/;
	    gopher_line_regex = /(?<gopher_type>.)(?<text>[^\t]*)(\t(?<selector>[^\t]*))?(\t(?<host>[^\t]*))?(\t(?<port>[^\t]*))?/;
		
		if(url_entry.text != "") {
		    gopher_load (url_entry.text, true);
		}
	}

	public void fix_cursor () {
		var w = text_view.get_window (TextWindowType.TEXT);
		w.set_cursor (new Gdk.Cursor.from_name (Gdk.Display.get_default (), "default"));
	}

	public void visit (string url, bool note) {
		url_entry.set_text (url);
		if (note) {
			history.prepend (url);
			future = new List<string> ();
		}
	}

	public void back () {
		if (history.length () > 1) {
			future.prepend (history.nth_data (0));
			history.remove_link (history.first ());
			string url = history.nth_data (0);
			gopher_load (url, false);
		}
	}
	
	public void forward () {
		if (future.length () > 0) {
			history.prepend (future.nth_data (0));
			string url = future.nth_data (0);
			future.remove_link (future.first ());
			gopher_load (url, false);
		}
	}
	
	public async void gopher_load (string url, bool note) {
		string host;
		int port;
		char gopher_type;
		string selector;

		TextBuffer buf = null;
		bool success;
		
		if (!gopher_parse_url (url, out host, out port, out gopher_type, out selector))
			return;
		
		spinner.start ();

		success = false;
		new Thread<int> ("gopher request", () => {
				success = gopher_request (url, host, port, gopher_type, selector, note, out buf);
				Idle.add (gopher_load.callback);
				return 0;
			});
		
		yield;

		if(success && buf != null) {
			visit (url, note);
			text_view.set_buffer (buf);
			fix_cursor ();
		}
		
		spinner.stop();
	}
	
	public bool gopher_parse_url (string url,
								  out string host,
								  out int port,
								  out char gopher_type,
								  out string selector) {
		MatchInfo match_info;

		host = "";
		port = 0;
		gopher_type = '0';
		selector = "/";
		
		if (gopher_url_regex.match (url, 0, out match_info)) {
			host = match_info.fetch_named ("host");
			
			string s_port = match_info.fetch_named ("port");
			if (s_port == null) s_port = "70";
			if (s_port == "") s_port = "70";
			port = int.parse(s_port);
			
			string gt = match_info.fetch_named ("gophertype");
			if (gt == null) {
				gopher_type = '1';
			}
			else {
				gopher_type = gt[0];
			}
			
			selector = match_info.fetch_named ("selector");
			if (selector == null) selector = "";
			
			// DBG
			stdout.printf("HOST: %s\n", host);
			stdout.printf("PORT: %d\n", port);
			stdout.printf("TYPE: %c\n", gopher_type);
			stdout.printf("SLCT: %s\n", selector);
			
			return true;
		}
		else {
			stdout.printf ("Invalid URL: %s\n", url);
			
			return false;
		}
	}
	
	public bool gopher_request (string input_url,
								string host, int port, char gopher_type, string selector,
								bool note,
								out TextBuffer buf2) {
		DataInputStream response;
		
		TextBuffer buf;
		TextIter iter;
		
		try {
			// Resolve hostname to IP address:
			Resolver resolver = Resolver.get_default ();
			List<InetAddress> addresses = resolver.lookup_by_name (host, null);
			InetAddress address = addresses.nth_data (0);
			
			// Connect:
			SocketClient client = new SocketClient ();
			SocketConnection conn = client.connect (new InetSocketAddress (address, (uint16) port));
			
			// Send HTTP GET request
			string message = @"%s\n\r".printf (selector);
			conn.output_stream.write (message.data);
			
			// Receive response
			response = new DataInputStream (conn.input_stream);
			
			buf = new TextBuffer (null);
			buf.get_start_iter (out iter);
		
			string line;
			try {
				while ((line = response.read_line (null)) != null) {
					if (gopher_type == '0') {
						buf.insert(ref iter, line + "\n", -1);
					}
					else if (gopher_type == '1') {
						gopher_page_handle_line (line, buf, ref iter);
					}
					else {
						stdout.printf ("Unhandled gopher type: %c\n", gopher_type);
						return false;
					}
				}
			} catch(IOError e) {
				stdout.printf ("IOError: %s\n", e.message);
				return false;
			}
		} catch (Error e) {
			stdout.printf ("Error: %s\n", e.message);
			return false;
		}

		buf2 = buf;

		return true;
	}

	void gopher_page_handle_line (string line, TextBuffer buf, ref TextIter iter) {
		MatchInfo match_info;

		if (line == ".") {
			buf.insert(ref iter, line + "\n", -1);
			return;
		}

		if (!gopher_line_regex.match (line, 0, out match_info)) {
			stdout.printf ("Gopher parsing error: %s\n", line);
			return;
		}

		char line_type = match_info.fetch_named ("gopher_type")[0];
		string text = match_info.fetch_named ("text");
		string line_selector = match_info.fetch_named ("selector");
		string line_host = match_info.fetch_named ("host");
		string s_line_port = match_info.fetch_named ("port");
		if (s_line_port == null) s_line_port = "70";
		int line_port = int.parse (s_line_port);
		
		if (line_type == 'i' || line_type == 'I') {
			buf.insert(ref iter, text + "\n", -1);
		}
		else if (line_type == '0' || line_type == '1') {
			string url = @"gopher://%s:%d/%c%s".printf (line_host, line_port, line_type, line_selector);
			
			insert_link_to (text, url, LinkType.GOPHE,
							buf, ref iter);
		}
		else if (line_type == 'h' || line_type == 'H') {
			string url = line_selector;
			
			if (url.has_prefix ("URL:")) {
				url = url.substring (4);
			}
			
		    insert_link_to (text, url, LinkType.HYPER,
							buf, ref iter);
		}
		else {
			stdout.printf ("Unknown gopher line type: %s\n", line);
		}
	}

	void insert_link_to (string line, string url, LinkType ty,
						 TextBuffer buf, ref TextIter iter) {
		string color = "";

		switch (ty) {
		case LinkType.GOPHE:
			color = "blue";
			break;
			
		case LinkType.HYPER:
			color = "red";
			break;
		}
		
		TextTag tag = buf.create_tag (null,
									  "foreground", color,
									  "underline", Pango.Underline.SINGLE,
									  null);
		tag.set_data ("link", url);
		
		tag.event.connect ((event_object, event, iter) => {
				if (event.type == Gdk.EventType.BUTTON_PRESS) {
					string link = tag.get_data ("link");
					
					switch (ty) {
					case LinkType.GOPHE:
						gopher_load (link, true);
						break;
						
					case LinkType.HYPER:
						try {
							if (!Gtk.show_uri (null, link, 0)) {
								stderr.printf ("Couldn't open URL: %s.\n", link);
							}
						}
						catch (Error e) {
							stderr.printf ("Couldn't open URL: %s.\n", link);
						}
						break;
					}
					
					return true;
				}
				else {
					return true;
				}
			});
		buf.insert_with_tags(ref iter, line + "\n", -1, tag, null);
	}
}
