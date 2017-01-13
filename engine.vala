using Gtk;
using GLib;

class Engine : Object {
    Entry url_entry;
	TextView text_view;
	Spinner spinner;

	List<string> history;
	List<string> future;
	
	public Engine (Entry url_entry, TextView text_view, Spinner spinner) {
		this.url_entry = url_entry;
		this.text_view = text_view;
		this.spinner = spinner;

	    history = new List<string> ();
		future = new List<string> ();
	}

	public void visit (string url, bool note) {
		url_entry.set_text (url);
		if (note) history.prepend (url);
	}

	public void back () {
		if (history.length () > 1) {
			history.remove_link (history.first ());
			string url = history.nth_data (0);
			stdout.printf("%s\n", url);
			gopher_load (url, false);
		}
	}

	public void forward () {
		
	}
	
	public bool gopher_parse_url (string url,
								  out string host,
								  out int port,
								  out char gopher_type,
								  out string selector) {
		try {
			Regex regex = /^(gopher:\/\/)?(?<host>[^\/:]*)(:(?<port>[0-9]+))?(\/((?<gophertype>.))?(?<selector>[^:]+))?\/?$/;
			MatchInfo match_info;
			if (regex.match (url, 0, out match_info)) {
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
		} catch (RegexError e) {
			stdout.printf ("URL parsing error %s\n", e.message);

			return false;
		}
	}

	public void gopher_request (string input_url,
									  string host, int port, char gopher_type, string selector,
									  bool note) {
		TextBuffer buf;
	
		try {
			// Resolve hostname to IP address:
			Resolver resolver = Resolver.get_default ();
			List<InetAddress> addresses = resolver.lookup_by_name (host, null);
stdout.printf ("4\n");
			InetAddress address = addresses.nth_data (0);

stdout.printf ("3\n");
			// Connect:
			SocketClient client = new SocketClient ();
			stdout.printf ("2 %d\n", port);
			SocketConnection conn = client.connect (new InetSocketAddress (address, (uint16) port));
stdout.printf ("1\n");
			// Send HTTP GET request
			string message = @"%s\n\r".printf (selector);
			conn.output_stream.write (message.data);
			stdout.printf ("REQ %s\n", message);
			
			// Receive response
			DataInputStream response = new DataInputStream (conn.input_stream);
			TextIter iter;
			buf = new TextBuffer (null);
			buf.get_start_iter (out iter);

			if (gopher_type == '0') {
				string status_line;
				while ((status_line = response.read_line (null).strip ()) != null) {
					buf.insert(ref iter, status_line + "\n", -1);
				}
			}
			else if (gopher_type == '1') {
				try {
					Regex regex = /(?<gopher_type>.)(?<text>[^\t]*)(\t(?<selector>[^\t]*))?(\t(?<host>[^\t]*))?(\t(?<port>[^\t]*))?/;
					MatchInfo match_info;
				
					string status_line;
					while ((status_line = response.read_line (null).strip ()) != null) {
						//DBG
						stdout.printf ("GOPHE %s\n", status_line);
						
						if (status_line == ".") {
							//
						}
						else if (regex.match (status_line, 0, out match_info)) {
							char line_type = match_info.fetch_named ("gopher_type")[0];
							string status = match_info.fetch_named ("text");
							string line_selector = match_info.fetch_named ("selector");
							string line_host = match_info.fetch_named ("host");
							string s_line_port = match_info.fetch_named ("port");
							if (s_line_port == null) s_line_port = "70";
							int line_port = int.parse (s_line_port);
							
							if (line_type == '0' || line_type == '1') {
								string url = @"gopher://%s:%d/%c%s".printf (line_host, line_port, line_type, line_selector);
							
								TextTag tag = buf.create_tag (null,
															  "foreground", "blue",
															  "underline", Pango.Underline.SINGLE,
															  null);
								tag.set_data ("link", url);
								tag.event.connect ((event_object, event, iter) => {
										if (event.type == Gdk.EventType.BUTTON_PRESS) {
											gopher_load (tag.get_data ("link"), true);
											//stdout.printf ("Gopher! %s\n", tag.get_data ("link"));
											return false;
										}
										else {
											return true;
										}
									});
								buf.insert_with_tags(ref iter, status + "\n", -1, tag, null);
							}
							else if (line_type == 'i') {
								buf.insert(ref iter, status + "\n", -1);
							}
							else {
								stdout.printf ("Gopher parsing error 3 %s\n", status_line);
								buf.insert(ref iter, status + "\n", -1);
							}
						}
						else {
							stdout.printf ("Gopher parsing error 1 %s\n", status_line);
						}
					}
				} catch (RegexError e) {
					stdout.printf ("Gopher parsing error 2 %s\n", e.message);
					return;
				}
			}
			else {
				stdout.printf ("Unhandled gopher type %c\n", gopher_type);
				return;
			}
		} catch (Error e) {
			stdout.printf ("Error: %s\n", e.message);
			return;
		}

		visit (input_url, note);
		text_view.set_buffer (buf);
	}
	
	public void gopher_load (string url, bool note) {
	    string host;
		int port;
		char gopher_type;
		string selector;
		
		stdout.printf ("DBG: %s\n", url);

		if (!gopher_parse_url (url, out host, out port, out gopher_type, out selector)) {
			return;
		}
		
		new Thread<int>("gopher request", ()=>{
				spinner.start();
				gopher_request (url, host, port, gopher_type, selector, note);
				spinner.stop();
				return 0;
			});
	}
}
