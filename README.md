# Setup Client-Server: Termux (Client) & Cloud Shell (Server)

Proyek ini mendemonstrasikan cara menggunakan Termux di perangkat Android Anda sebagai remote control (client) untuk mengeksekusi perintah di Google Cloud Shell (server) Anda. Komunikasi dilakukan melalui API web yang dihosting di Cloud Shell dan diekspos menggunakan `ngrok`.

## Arsitektur

-   **Client:** Termux di Android
-   **Server:** Google Cloud Shell
-   **Metode Komunikasi:** HTTP POST Request dengan API Key melalui terowongan `ngrok`.
-   **Direktori Kerja:** `papan/`

## Komponen

1.  **Server Flask (Python):** Sebuah aplikasi web sederhana yang berjalan di Cloud Shell, mendengarkan permintaan POST, mengautentikasi menggunakan API Key, dan menjalankan perintah yang diterima.
2.  **`ngrok`:** Alat tunneling yang membuat URL publik aman yang mengarahkan lalu lintas ke server Flask lokal Anda di Cloud Shell, melewati proxy autentikasi Google.

## Setup di Google Cloud Shell (Server)

Semua langkah ini perlu dilakukan di sesi Google Cloud Shell Anda.

### 1. Masuk ke Direktori Kerja

Pastikan Anda berada di dalam folder `papan`:

```bash
cd papan
```

### 2. File Server Flask (`app.py`)

Pastikan file `app.py` ada di dalam folder `papan` dengan konten berikut:

```python
import subprocess
import os
from flask import Flask, request, jsonify

# --- Konfigurasi ---
# Gunakan secret key yang diberikan oleh pengguna.
SECRET_KEY = "r9Tk3LP5X0mGjQYw" # Ganti dengan API Key Anda
# Dapatkan port dari environment variable, default ke 8080 jika tidak ada.
PORT = int(os.environ.get("PORT", 8080))

app = Flask(__name__)

@app.route('/execute', methods=['POST'])
def execute_command():
    # 1. Periksa header otorisasi
    provided_key = request.headers.get('X-Api-Key')
    if not provided_key or provided_key != SECRET_KEY:
        return jsonify({"error": "Unauthorized"}), 401

    # 2. Dapatkan data JSON dari request
    data = request.get_json()
    if not data or 'command' not in data:
        return jsonify({"error": "Bad request, 'command' field is missing"}), 400

    command = data['command']

    # 3. Jalankan perintah dengan aman
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30,
            check=False
        )
        # 4. Kembalikan output
        return jsonify({
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode
        })
    except subprocess.TimeoutExpired:
        return jsonify({"error": "Command timed out"}), 408
    except Exception as e:
        return jsonify({"error": "An unexpected error occurred: {str(e)}"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=PORT)
```

### 3. Instalasi dan Konfigurasi `ngrok`

1.  **Unduh dan Instal `ngrok`:**
    ```bash
    pkill ngrok || true # Hentikan ngrok lama jika ada
    wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -O ngrok-v3-stable-linux-amd64.tgz
    tar xvzf ngrok-v3-stable-linux-amd64.tgz
    mv ngrok ~/bin/ && chmod +x ~/bin/ngrok
    rm ngrok-v3-stable-linux-amd64.tgz # Bersihkan file unduhan
    ```
2.  **Konfigurasi Authtoken `ngrok`:**
    Anda perlu akun `ngrok` dan authtoken untuk menggunakan `ngrok`. Daftar di [ngrok.com](https://ngrok.com) dan dapatkan authtoken Anda.
    ```bash
    ~/bin/ngrok authtoken <AUTHTOKEN_ANDA>
    ```
    Ganti `<AUTHTOKEN_ANDA>` dengan authtoken yang Anda dapatkan dari dasbor `ngrok` Anda.

### 4. Menjalankan Server dan `ngrok`

Jalankan kedua proses ini di latar belakang agar tetap berjalan.

```bash
# Jalankan server Flask
nohup flask --app papan/app.py run --host=0.0.0.0 --port=8080 > flask.log 2>&1 &

# Jalankan ngrok
nohup ~/bin/ngrok http 8080 > ngrok.log 2>&1 &
```

### 5. Mendapatkan URL `ngrok`

Setelah `ngrok` berjalan, tunggu sekitar 15-20 detik, lalu dapatkan URL publiknya dengan:

```bash
curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url'
```
URL ini akan terlihat seperti `https://<random-subdomain>.ngrok-free.dev`.

### 6. Menghentikan Proses

Jika Anda ingin menghentikan server dan `ngrok`, gunakan perintah berikut:

```bash
pkill -f flask
pkill ngrok
```

## Penggunaan dari Termux (Client)

Untuk mengirim perintah dari Termux ke Cloud Shell Anda:

1.  **Instal `curl`** di Termux jika belum ada:
    ```bash
pkg install curl
    ```
2.  **Kirim Perintah:** Gunakan perintah `curl` berikut. Ganti `<URL_NGROK_ANDA>` dengan URL yang Anda dapatkan di langkah server, dan `<API_KEY_ANDA>` dengan kunci rahasia yang Anda tetapkan di `app.py`.

    Contoh: Jalankan perintah `pwd`
    ```bash
    curl -X POST \
      -H "Content-Type: application/json" \
      -H "X-Api-Key: r9Tk3LP5X0mGjQYw" \
      -d '{"command": "pwd"}' \
      https://julienne-vascular-apolitically.ngrok-free.dev/execute
    ```
    Anda akan menerima respons JSON yang berisi `stdout`, `stderr`, dan `returncode` dari perintah yang dieksekusi.

    Ubah nilai `"pwd"` di bagian `-d` dengan perintah Linux apa pun yang ingin Anda jalankan.

---
**Catatan:** URL `ngrok` gratis dapat berubah setiap kali Anda memulai ulang `ngrok`. Anda perlu mendapatkan URL baru setiap kali Anda menjalankan ulang `ngrok`.
