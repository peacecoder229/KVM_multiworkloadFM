# echo-client.py

import socket
import sys

result_file = sys.argv[1]

HOST = "192.168.122.1"  # The server's hostname or IP address
PORT = 65432  # The port used by the server

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    try:
        s.connect((HOST, PORT))
        msg = f"{result_file}: Done"
        s.send(msg.encode())
        
        #data = s.recv(1024)
    except socket.error:
        print("Server is not listening anymore.")
#print(f"Received {data!r}")
