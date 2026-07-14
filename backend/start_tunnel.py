import subprocess
import sys
import time

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
subdomain = sys.argv[2] if len(sys.argv) > 2 else "faceguard-api-vins"
cmd = f"npx localtunnel --port {port} --subdomain {subdomain}"

print(f"Starting auto-reconnecting localtunnel for port {port} with subdomain {subdomain}...")
while True:
    try:
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, shell=True, text=True, bufsize=1)
        for line in iter(process.stdout.readline, ""):
            print(line, end="")
            sys.stdout.flush()
        process.wait()
    except Exception as e:
        print(f"Error in tunnel process: {e}")
    print("Tunnel connection lost. Reconnecting in 3 seconds...")
    time.sleep(3)
