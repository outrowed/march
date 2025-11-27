#!/usr/bin/bash

# Create the directory for password hashes
mkdir -p passwords

echo "---- Multi-User Password Setup ----"
echo "Enter a username to set the password; you will be prompted for extra groups."
echo "Enter 'root' to set the root password (no extra groups allowed)."
echo "Type '.exit' to stop when finished."
echo "-----------------------------------"

while true; do
    echo ""
    read -p "Enter username to configure: " username

    if [[ "$username" == ".exit" ]]; then
        exit 0
    fi

    if [[ -z "$username" ]]; then
        echo "Username cannot be empty."
        continue
    fi

    filename="$username"
    groups=""

    if [[ "$username" == "root" ]]; then
        echo " -> User: $username"
        echo " -> Extra groups are not allowed for root."
    else
        read -p "Enter extra groups for $username (comma-separated, blank for none): " groups_input
        # Strip whitespace from the comma-separated list
        groups="${groups_input//[[:space:]]/}"
        if [[ -n "$groups" ]]; then
            filename="${username}+${groups}"
            echo " -> User: $username"
            echo " -> Groups: $groups"
        else
            echo " -> User: $username"
            echo " -> No extra groups specified."
        fi
    fi

    # Check if we are overwriting an existing user
    if [[ -f "passwords/$filename" ]]; then
        read -p "User '$username' already exists. Overwrite? [y/N]: " confirm
        if [[ "$confirm" != "y" ]]; then
            continue
        fi
    fi

    echo "Enter password for $username:"
    # Generate hash and save to passwords/<filename>
    # We save using '<username>+<groups>' so the installer sees the extra groups later
    openssl passwd -6 > "passwords/$filename"
    
    echo "Saved hash for user: $username"
    echo "Press Ctrl+C to stop when finished."
done
