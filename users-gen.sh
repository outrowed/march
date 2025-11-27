#!/usr/bin/bash

# Create the directory for password hashes
mkdir -p passwords

echo "--- Multi-User Password Setup ---"
echo "Format: username (e.g. 'example') or username+groups (e.g. 'example+wheel,samba')"
echo "Enter 'root' to set the root password."
echo "Press Ctrl+C to stop when finished."
echo "-----------------------------------"

while true; do
    echo ""
    read -p "Enter username to configure: " input_name

    if [[ -z "$input_name" ]]; then
        echo "Username cannot be empty."
        continue
    fi

    # Only split if a '+' exists
    if [[ "$input_name" == *"+"* ]]; then
        username="${input_name%%+*}"
        groups="${input_name#*+}"
        echo " -> User: $username"
        echo " -> Groups: $groups"
    else
        username="$input_name"
        groups=""
        echo " -> User: $username"
        echo " -> No group specified."
    fi

    # Don't allow groups for root
    if [[ "$username" == "root" ]] && [[ -n "$groups" ]]; then
        echo "Error: You cannot add extra groups to 'root'. Please just type 'root'."
        continue
    fi

    # Check if we are overwriting an existing user
    if [[ -f "passwords/$input_name" ]]; then
        read -p "User '$username' already exists. Overwrite? [y/N]: " confirm
        if [[ "$confirm" != "y" ]]; then
            continue
        fi
    fi

    echo "Enter password for $username:"
    # Generate hash and save to passwords/<filename>
    # We save using 'input_name' so the installer sees the '+groups' part later
    openssl passwd -6 > "passwords/$input_name"
    
    echo "Saved hash for user: $username"
done