# %%bash

#!/bin/bash

# Ambil argumen pertama sebagai mode input
input="$1"

# Mapping dari kata ke perintah
path="/home/akunku11_mb/shell"
if [[ "$input" == "buat" ]]; then
  apt_mode="install"
  pip_mode="install"
elif [[ "$input" == "hapus" ]]; then
  apt_mode="remove --purge"
  pip_mode="uninstall"
else
  echo "❌ Mode tidak dikenal. Gunakan 'buat' atau 'hapus'."
  exit 1
fi

## %%bash
## 🔧 Proses package.txt
# Jika proyekmu memiliki file 'package.txt', kita akan meng-$inputnya di sini.
if test -f "$path/package.txt"; then
    if [[ "$apt_mode" == "install" ]]; then
        sudo apt update
        sudo apt upgrade -y
        grep -vE '^\s*#|^\s*$' "$path/package.txt" | xargs sudo apt $apt_mode -y
    else
        grep -vE '^\s*#|^\s*$' "$path/package.txt" | xargs sudo apt $apt_mode -y
    fi
else 
    echo "📦 Tidak ada file package.txt, jadi tidak ada yang perlu di-$input."
fi

## %%bash
## 🐍 Proses requirements.txt
# Jika proyekmu memiliki file 'requirements.txt', kita akan meng-$inputnya di sini.
if test -f "$path/requirements.txt"; then
    if [[ "$pip_mode" == "install" ]]; then
        sudo pip $pip_mode -r "$path/requirements.txt"
        sudo pip $pip_mode --upgrade pip
    else
        grep -vE '^\s*#|^\s*$' "$path/requirements.txt" | xargs sudo pip $pip_mode -y
    fi
else
    echo "🐍 Tidak ada file requirements.txt, jadi tidak ada yang perlu di-$input."
fi