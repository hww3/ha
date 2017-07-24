//
// make a serial device available via ip
//
// note: this script provides no active authentication,
// so must not be used on a network that has internet
// access or untrusted devices. 
//
// it allows one connection at a time from a host listed
// in the valid hosts array.

// full device path to the serial port we wish to make available
string device = "/dev/ttyUSB0";

// mapping containing the serial connection options (baud rate, etc)
mapping serial_opts = (["ispeed": 115200, "ospeed": 115200,
    "ECHO":0,"ICANON":0,"VMIN":0,"VTIME":0]);

// tcp port number to listen on
int port_number = 1234;

// list of hosts we accept network connections from.
array valid_hosts = ({"apollo.local"});

Stdio.Port port;
Stdio.File f;

Stdio.File serial;

string serial_buffer = "";
string network_buffer = "";

int main() {
  open_port();
  return -1;
}

int open_serial() {
  mixed e = catch {
  serial = Stdio.File(device, "rw");
  serial->tcsetattr(serial_opts);
  serial->set_nonblocking();
  serial->set_read_callback(sread_cb);
  serial->set_write_callback(swrite_cb);
  serial->set_close_callback(sclose_cb);
  };

  if(e || !f || !f->is_open()) return 0;
  else return 1;
}

void close_serial() {
  serial->close();
  serial = 0;
}

void open_port() {
  f = 0;
  port = Stdio.Port(port_number, accept_cb);
}

void close_port() {
  port->close();
  port = 0;
}

int  verify_connection(Stdio.File f)
{
  string addr = (f->query_address()/" ")[0];
  if(search(valid_hosts, addr) != -1) return 1;
  foreach(valid_hosts;;string vh) {
    array r = System.gethostbyname(vh);
    if(!r) continue;
    foreach(r[1]; int i; string a)
      if(a == addr) return 1;
  }
  return 1;
}


void accept_cb(mixed id) {
  f = port->accept();
  string addr = (f->query_address()/" ")[0];
  werror("connection from: %O\n", addr);
  if(!verify_connection(f)) { f->close(); f = 0; }
  close_port();
  if(!open_serial()) { werror("access denied\n"); close_cb(0); return; }
  werror("connected\n");
  f->set_nonblocking();
  f->set_read_callback(read_cb);
  f->set_write_callback(write_cb);
  f->set_close_callback(close_cb);
}

int read_cb(mixed id, string data) {
  write("network received %O\n", data);
  data -= ("\r");
  data -= ("\n");
  if(!sizeof(data)) return 0;
  else data = "\r" + data + "\r";
  int x = serial->write(data, 1);
  werror("wrote %d bytes of %d to serial\n", x, sizeof(data));
  if(x < sizeof(data)) 
    serial_buffer += data[x..];
}

int sread_cb(mixed id, string data) {
  write("serial received %O\n", data);
  int x = f->write(data, 1);
  werror("wrote %d bytes of %d to network\n", x, sizeof(data));
  if(x < sizeof(data)) 
    network_buffer += data[x..];
}

int write_cb(mixed id) {
  if(!sizeof(network_buffer)) return 0;
  int x = f->write(network_buffer, 1);
  if(x == sizeof(network_buffer)) 
    network_buffer = "";
  else 
    network_buffer = network_buffer[x..];
  return x;
}

int swrite_cb(mixed id) {
  if(!sizeof(serial_buffer)) return 0;
  int x = f->write(serial_buffer, 1);
  if(x == sizeof(serial_buffer)) 
    serial_buffer = "";
  else 
    serial_buffer = serial_buffer[x..];
  return x;
}

int sclose_cb(mixed id) {
  close_cb(0);
}

int close_cb(mixed id) {
  if(f)
    f->close();
  f = 0;
  close_serial();
  open_port();
  return 0;
}
