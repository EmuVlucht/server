# %%bash

#!/bin/bash

# Ambil argumen pertama sebagai mode
input="$1"

# Mapping dari kata ke perintah pip
if [[ "$input" == "buat" ]]; then
  mode="install"
elif [[ "$input" == "hapus" ]]; then
  mode="uninstall"
else
  echo "❌ Mode tidak dikenal. Gunakan 'buat' atau 'hapus'."
  exit 1
fi

path="/home/akunku11_mb/shell"

## %%bash
# Kalau ada file package.txt
if test -f $path/package.txt
then
sudo apt update
sudo apt upgrade -y
grep -vE '^\s*#|^\s*$' $path/package.txt | xargs sudo apt $mode -y
else
echo "Tidak ada file package.txt, jadi tidak ada yang perlu di$mode."
fi

## %%bash
# Jika proyekmu memiliki file 'requirements.txt', kita akan meng$modenya di sini.
if test -f $path/requirements.txt
then
sudo pip $mode -r $path/requirements.txt
sudo pip $mode --upgrade pip
else echo "Tidak ada file requirements.txt, jadi tidak ada yang perlu di$mode."
fi
