#!/bin/bash

set -e  # Exit if there is any error

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run this script as root (use sudo)"
    exit 1
fi

LATEST_TAG_VERSION=`curl -s https://api.github.com/repos/NyarchLinux/NyarchLinux/releases/latest | grep "tag_name" | awk -F'"' '/tag_name/ {print $4}'`
RELEASE_LINK="https://github.com/NyarchLinux/NyarchLinux/releases/download/$LATEST_TAG_VERSION/"
TAG_PATH="https://raw.githubusercontent.com/NyarchLinux/NyarchLinux/refs/tags/$LATEST_TAG_VERSION/Gnome/"

RED='\033[0;31m'
NC='\033[0m'

curl https://raw.githubusercontent.com/NyarchLinux/NyarchLinux/main/Gnome/etc/skel/.config/neofetch/ascii70
echo -e "$RED\n\nWelcome to Nyarch Linux SYSTEM-WIDE customization installer! $NC"
echo -e "${RED}This will install for ALL users on the system.$NC\n"

check_gnome_version() {
  GNOME_VERSION=`gnome-session --version`
  GNOME_VERSION_NUMBER=${GNOME_VERSION##* }
  GNOME_VERSION_MAJOR=${GNOME_VERSION_NUMBER%%.*}
  if [ "$GNOME_VERSION_MAJOR" -lt 47 ]; then
    echo "You need Gnome version 47 or above."
    exit
  fi
}

get_tarball() {
    file_path=/tmp/NyarchLinux.tar.gz
    url=${RELEASE_LINK}NyarchLinux.tar.gz

    if [ ! -f "$file_path" ]; then
        echo "Downloading Nyarch tarball from $url"
        wget -q -O "$file_path" "$url"
        cd /tmp
        tar -xvf /tmp/NyarchLinux.tar.gz
    else
        echo "Using cached Nyarch tarball"
    fi
}

install_extensions_systemwide() {
  check_gnome_version
  
  # Install to /etc/skel for new users
  echo "Installing extensions to /etc/skel for new users..."
  mkdir -p /etc/skel/.local/share/gnome-shell
  get_tarball
  cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/gnome-shell/extensions /etc/skel/.local/share/gnome-shell/
  
  # Install for all existing users
  echo "Installing extensions for all existing users..."
  for user_home in /home/*; do
    if [ -d "$user_home" ]; then
      username=$(basename "$user_home")
      echo "Installing for user: $username"
      
      # Create directory structure
      sudo -u "$username" mkdir -p "$user_home/.local/share/gnome-shell"
      
      # Backup existing extensions
      if [ -d "$user_home/.local/share/gnome-shell/extensions" ]; then
        mv "$user_home/.local/share/gnome-shell/extensions" "$user_home/.local/share/gnome-shell/extensions-backup-$(date +%s)"
      fi
      
      # Copy extensions
      cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/gnome-shell/extensions "$user_home/.local/share/gnome-shell/"
      chown -R "$username:$username" "$user_home/.local/share/gnome-shell/extensions"
      chmod -R 755 "$user_home/.local/share/gnome-shell/extensions"
    fi
  done
  
  # Install material you globally
  cd /tmp
  if [ ! -d "material-you-colors" ]; then
    git clone https://github.com/FrancescoCaracciolo/material-you-colors.git
  fi
  cd material-you-colors
  make build
  
  # Install for each user
  for user_home in /home/*; do
    if [ -d "$user_home" ]; then
      username=$(basename "$user_home")
      sudo -u "$username" make install
      npm install --prefix "$user_home/.local/share/gnome-shell/extensions/material-you-colors@francescocaracciolo.github.io"
      
      cd "$user_home/.local/share/gnome-shell/extensions/material-you-colors@francescocaracciolo.github.io"
      if [ ! -d "adwaita-material-you" ]; then
        git clone https://github.com/francescocaracciolo/adwaita-material-you
      fi
      cd adwaita-material-you
      sudo -u "$username" bash local-install.sh
      chown -R "$username:$username" "$user_home/.local/share/gnome-shell/extensions/material-you-colors@francescocaracciolo.github.io"
    fi
  done
  
  # Install material you icons for all users
    cd /tmp
    if [ ! -d "Tela-circle-icon-theme" ]; then
      git clone https://github.com/vinceliuice/Tela-circle-icon-theme
    fi
    cd Tela-circle-icon-theme
    # Install to /usr/local/share/icons
    ./install.sh -d /usr/local/share/icons 2>/dev/null || {
      mkdir -p /usr/local/share/icons
      cp -rf src/* /usr/local/share/icons/
    }
  done
  
  # Also install to /etc/skel
  mkdir -p /etc/skel/.config/nyarch
  cd /etc/skel/.config/nyarch
  if [ ! -d "Tela-circle-icon-theme" ]; then
    git clone https://github.com/vinceliuice/Tela-circle-icon-theme
  fi
}

install_nyaofetch() {
  cd /usr/bin
  # Download scripts to system-wide location
  wget -O /usr/local/bin/nekofetch ${TAG_PATH}usr/local/bin/nekofetch
  wget -O /usr/local/bin/nyaofetch ${TAG_PATH}usr/local/bin/nyaofetch
  # Give execution permissions
  chmod +x /usr/local/bin/nekofetch
  chmod +x /usr/local/bin/nyaofetch
}

configure_neofetch() {
  get_tarball
  
  # Install to /etc/skel
  mkdir -p /etc/skel/.config/fastfetch
  cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/fastfetch/* /etc/skel/.config/fastfetch/
  
  # Install for all existing users
  for user_home in /home/*; do
    if [ -d "$user_home" ]; then
      username=$(basename "$user_home")
      
      # Backup existing
      if [ -d "$user_home/.config/fastfetch" ]; then
        mv "$user_home/.config/fastfetch" "$user_home/.config/fastfetch-backup-$(date +%s)"
      fi
      
      # Install new
      mkdir -p "$user_home/.config/fastfetch"
      cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/fastfetch/* "$user_home/.config/fastfetch/"
      chown -R "$username:$username" "$user_home/.config/fastfetch"
    fi
  done
}

download_wallpapers() {
  cd /tmp
  wget ${RELEASE_LINK}wallpaper.tar.gz
  tar -xvf wallpaper.tar.gz
  cd wallpaper 
  # Install system-wide (modify install.sh if needed to install to /usr/share/backgrounds)
  bash install.sh
}

download_icons() {
  cd /tmp 
  wget ${RELEASE_LINK}icons.tar.gz
  tar -xvf icons.tar.gz
  
  # Install to /usr/local/share/icons for system-wide access
  mkdir -p /usr/local/share/icons
  cp -rf Tela-circle-MaterialYou /usr/local/share/icons/
}

set_themes() {
  get_tarball
  
  # Install themes to /usr/local/share/themes for system-wide access
  mkdir -p /usr/local/share/themes
  cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/themes/* /usr/local/share/themes/
  
  # GTK configs MUST be per-user, install to /etc/skel and existing users
  mkdir -p /etc/skel/.config
  cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-3.0 /etc/skel/.config/
  cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-4.0 /etc/skel/.config/
  
  # Install GTK configs for all existing users (NOT themes)
  for user_home in /home/*; do
    if [ -d "$user_home" ]; then
      username=$(basename "$user_home")
      
      # Backup existing GTK configs only
      [ -d "$user_home/.config/gtk-3.0" ] && mv "$user_home/.config/gtk-3.0" "$user_home/.config/gtk-3.0-backup-$(date +%s)"
      [ -d "$user_home/.config/gtk-4.0" ] && mv "$user_home/.config/gtk-4.0" "$user_home/.config/gtk-4.0-backup-$(date +%s)"
      
      # Install GTK configs only (NOT themes)
      mkdir -p "$user_home/.config"
      cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-3.0 "$user_home/.config/"
      cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-4.0 "$user_home/.config/"
      
      chown -R "$username:$username" "$user_home/.config/gtk-3.0"
      chown -R "$username:$username" "$user_home/.config/gtk-4.0"
    fi
  done
}

configure_kitty() {
  # Install to /etc/skel
  mkdir -p /etc/skel/.config/kitty
  wget -O /etc/skel/.config/kitty/kitty.conf ${TAG_PATH}etc/skel/.config/kitty/kitty.conf
  
  # Install for all existing users
  for user_home in /home/*; do
    if [ -d "$user_home" ]; then
      username=$(basename "$user_home")
      mkdir -p "$user_home/.config/kitty"
      
      # Backup existing
      [ -f "$user_home/.config/kitty/kitty.conf" ] && mv "$user_home/.config/kitty/kitty.conf" "$user_home/.config/kitty/kitty-backup-$(date +%s).conf"
      
      # Install new
      wget -O "$user_home/.config/kitty/kitty.conf" ${TAG_PATH}etc/skel/.config/kitty/kitty.conf
      chown -R "$username:$username" "$user_home/.config/kitty"
    fi
  done
}

flatpak_overrides() {
  flatpak override --filesystem=xdg-config/gtk-3.0
  flatpak override --filesystem=xdg-config/gtk-4.0
}

install_flatpaks() {
  # Add flathub
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  # Themes
  flatpak install -y org.gtk.Gtk3theme.adw-gtk3 org.gtk.Gtk3theme.adw-gtk3-dark
  # Apps
  flatpak install -y flathub info.febvre.Komikku
  flatpak install -y flathub com.github.tchx84.Flatseal
  flatpak install -y flathub de.haeckerfelix.Shortwave
  flatpak install -y flathub org.gnome.Lollypop
  flatpak install -y flathub de.haeckerfelix.Fragments
  flatpak install -y flathub com.mattjakeman.ExtensionManager
  flatpak install -y flathub it.mijorus.gearlever
}

install_nyarch_apps() {
  cd /tmp
  
  # CatgirlDownloader
  wget https://github.com/nyarchlinux/catgirldownloader/releases/latest/download/catgirldownloader.flatpak 
  flatpak install -y catgirldownloader.flatpak

  # NyarchWizard
  wget https://github.com/nyarchlinux/nyarchwizard/releases/latest/download/wizard.flatpak 
  flatpak install -y wizard.flatpak

  # NyarchTour
  wget https://github.com/nyarchlinux/nyarchtour/releases/latest/download/nyarchtour.flatpak 
  flatpak install -y nyarchtour.flatpak

  # NyarchCustomize
  wget https://github.com/nyarchlinux/nyarchcustomize/releases/latest/download/nyarchcustomize.flatpak 
  flatpak install -y nyarchcustomize.flatpak
 
  # Nyarch Scripts
  wget https://github.com/nyarchlinux/nyarchscript/releases/latest/download/nyarchscript.flatpak
  flatpak install -y nyarchscript.flatpak

  # Waifu Downloader
  wget https://github.com/nyarchlinux/waifu-downloader/releases/latest/download/waifudownloader.flatpak
  flatpak install -y waifudownloader.flatpak
}

install_nyarch_assistant() {
  cd /tmp
  wget https://github.com/nyarchlinux/nyarchassistant/releases/latest/download/nyarchassistant.flatpak
  flatpak install -y nyarchassistant.flatpak
}

install_nyarch_updater() {
  cd /tmp
  wget https://github.com/nyarchlinux/nyarchupdater/releases/latest/download/nyarchupdater.flatpak
  flatpak install -y nyarchupdater.flatpak
  echo 241104 > /version
}

configure_gsettings() {
  check_gnome_version
  get_tarball
  
  # For each user with an active GNOME session, apply settings
  for user_home in /home/*; do
    if [ -d "$user_home" ]; then
      username=$(basename "$user_home")
      echo "Configuring gsettings for user: $username"
      
      # Get user's UID
      user_uid=$(id -u "$username")
      
      # Backup old settings
      sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$user_uid/bus" dconf dump / > "$user_home/dconf-backup-$(date +%s).txt"
      
      # Load new settings
      cd /tmp/NyarchLinux/Gnome/etc/dconf/db/local.d
      sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$user_uid/bus" dconf load / < 06-extensions
      sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$user_uid/bus" dconf load / < 02-interface
      sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$user_uid/bus" dconf load / < 04-wmpreferences
      sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$user_uid/bus" dconf load / < 03-background
    fi
  done
}

add_pywal() {
  # Add to /etc/skel/.bashrc
  if ! grep -q "cache/wal/sequences" /etc/skel/.bashrc 2>/dev/null; then
    cat >> /etc/skel/.bashrc << 'EOF'

# Pywal
if [[ -f "$HOME/.cache/wal/sequences" ]]; then
    (cat $HOME/.cache/wal/sequences)
fi
EOF
  fi
  
  # Add to all existing users
  for user_home in /home/*; do
    if [ -d "$user_home" ]; then
      username=$(basename "$user_home")
      if ! grep -q "cache/wal/sequences" "$user_home/.bashrc" 2>/dev/null; then
        cat >> "$user_home/.bashrc" << 'EOF'

# Pywal
if [[ -f "$HOME/.cache/wal/sequences" ]]; then
    (cat $HOME/.cache/wal/sequences)
fi
EOF
        chown "$username:$username" "$user_home/.bashrc"
      fi
    fi
  done
}

## EXECUTION PART

check_gnome_version

read -r -p "Have you installed all the dependencies listed in the github page of this script? (Y/n): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "Cool! We can go ahead"
else
  echo "You need to have already installed the dependencies listed on github before running this script!"
  exit
fi

read -r -p "Do you want to install Gnome extensions system-wide? (Y/n): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  install_extensions_systemwide
  echo "Gnome extensions installed system-wide!"
fi

read -r -p "[SYSTEM] Do you want to install Nekofetch and Nyaofetch system-wide? (Y/n): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  install_nyaofetch
  configure_neofetch
  echo "Nyaofetch and Neofetch installed system-wide!"
fi

read -r -p "Download Nyarch wallpapers? (Y/n): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  download_wallpapers
  echo "Wallpapers downloaded!"
fi

read -r -p "Do you want to download icons system-wide? (Y/n): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  download_icons
  echo "Icons installed system-wide!"
fi

read -r -p "Do you want to download themes system-wide? (Y/n): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  set_themes
  echo "Themes installed system-wide!"
fi

read -r -p "Do you want to apply customizations to kitty terminal system-wide? (Y/n): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  configure_kitty
  echo "Kitty configured system-wide!"
fi

read -r -p "Do you want to add pywal theming to all users' ~/.bashrc? (Y/n): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  add_pywal
  echo "pywal configured system-wide!"
fi

read -r -p "Do you want to apply GTK themes to flatpak apps? (Y/n): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  flatpak_overrides
  echo "Flatpak themes configured!"
fi

read -r -p "Do you want to install suggested flatpaks? (Y/n): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  install_flatpaks
  echo "Suggested apps installed!"
fi

read -r -p "[SYSTEM] Do you want to install Nyarch Exclusive applications? (Y/n): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  install_nyarch_apps
  echo "Nyarch apps installed!"
fi

read -r -p "[SYSTEM] Do you want to install Nyarch Assistant? (Y/n): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then 
  install_nyarch_assistant
  echo "Nyarch Assistant installed!"
fi 

read -r -p "[SYSTEM] Do you want to install Nyarch Updater? (Y/n): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  install_nyarch_updater
  echo "Nyarch Updater installed!"
fi

read -r -p "Do you want to configure Gnome settings for all users? (Y/n): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  configure_gsettings
  echo "Gnome settings configured for all users!"
fi

echo -e "$RED Installation complete! All users need to log out and log back in to see the results! $NC"