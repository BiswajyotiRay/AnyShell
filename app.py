from flask import Flask, jsonify, render_template
import psutil
import time
import requests
import logging
import os
import subprocess

app = Flask(__name__, template_folder='templates')

# Logging setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configurations
URL_TO_PING = os.getenv("URL_TO_PING", "https://google.com")

def read_ssh_url():
    """Reads SSH URL from file."""
    try:
        with open("ssh_url.txt", "r") as file:
            return file.read().strip()
    except FileNotFoundError:
        return "not available"

ssh_url = read_ssh_url()

def format_uptime(seconds):
    days = seconds // (24 * 3600)
    seconds %= (24 * 3600)
    hours = seconds // 3600
    seconds %= 3600
    minutes = seconds // 60
    seconds %= 60
    return f"{int(days)}d {int(hours)}h {int(minutes)}m {int(seconds)}s"

def get_ping(url=URL_TO_PING):
    try:
        start_time = time.time()
        response = requests.get(url, timeout=5)
        end_time = time.time()
        response_time = (end_time - start_time) * 1000  # ms
        if response.status_code == 200:
            return f"{response_time:.0f} ms"
        else:
            return "Failed"
    except requests.RequestException as e:
        logger.error(f"Ping error: {e}")
        return "Failed"

def get_bandwidth_usage():
    counters = psutil.net_io_counters()
    upload_bandwidth = round(counters.bytes_sent / (1024 ** 2), 2)  # MB
    download_bandwidth = round(counters.bytes_recv / (1024 ** 2), 2)  # MB

    return {
        "upload_bandwidth": upload_bandwidth,
        "download_bandwidth": download_bandwidth
    }

def get_server_status():
    try:
        cpu_usage = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')

        disk_used = round(disk.used / (1024 ** 3), 2)  # GB
        disk_total = round(disk.total / (1024 ** 3), 2)
        disk_percent = disk.percent

        memory_total = round(memory.total / (1024 ** 3), 2)
        memory_used = round(memory.used / (1024 ** 3), 2)
        memory_percent = memory.percent

        uptime_seconds = time.time() - psutil.boot_time()
        uptime_human = format_uptime(uptime_seconds)

        current_tasks = len(list(psutil.process_iter()))
        ping_status = get_ping()

        bandwidth = get_bandwidth_usage()

        ssh_url = read_ssh_url()

        return {
            "status": "ok",
            "uptime": uptime_human,
            "ping_status": ping_status,
            "current_tasks": current_tasks,
            "cpu_usage": cpu_usage,
            "memory_total": memory_total,
            "memory_used": memory_used,
            "memory_percent": memory_percent,
            "disk_total": disk_total,
            "disk_used": disk_used,
            "disk_percent": disk_percent,
            **bandwidth,
            "ssh_url": ssh_url,
            
        }
    except Exception as e:
        logger.error(f"Error fetching server status: {e}")
        return {"status": "error", "message": str(e)}

@app.route('/regenerate', methods=['POST'])
def regenerate():
    global ssh_url
    try:
        subprocess.Popen(["bash", "tmate.sh"])
        time.sleep(3)
        return jsonify({"status": "success"})
    except Exception as e:
        logger.error(f"Error running tmate.sh: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/status', methods=['GET'])
def status():
    return jsonify(get_server_status())

@app.route('/')
def home():
    return render_template("index.html")