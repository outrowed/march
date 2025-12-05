#!/usr/bin/bash

# Create the directory for password hashes
mkdir -p passwords

required_user="$1"
required_user_created=false
root_password_created=false

# Mark as created if a password hash already exists for the required user
if [[ -n "$required_user" ]]; then
    if ls passwords/"${required_user}" passwords/"${required_user}"+* > /dev/null 2>&1; then
        required_user_created=true
    fi
fi

# Mark root as created if a password hash already exists for root
if ls passwords/root passwords/root+* > /dev/null 2>&1; then
    root_password_created=true
fi

echo "---- Multi-User Password Setup ----"
echo "Enter a username to set the password; you will be prompted for extra groups."
echo "Enter 'root' to set the root password (no extra groups allowed)."
echo "Type '.exit' to stop when finished."
echo "Type '.exit-without-root' to stop even if root has no password."
echo "-----------------------------------"
echo ""

if [[ -n "$required_user" ]]; then
    echo "Required user must be created: ${required_user}"
else
    echo "No required user specified."
fi

while true; do
    echo ""
    read -p "Enter username to configure: " username

    if [[ -z "$username" ]]; then
        echo "Username cannot be empty."
        continue
    fi

    if [[ "$username" == ".exit-without-root" ]]; then
        if [[ -n "$required_user" && "$required_user_created" != true ]]; then
            echo "Required user '${required_user}' must be created before exiting."
            continue
        fi
        exit 0
    fi

    if [[ "$username" == ".exit" ]]; then
        if [[ -n "$required_user" && "$required_user_created" != true ]]; then
            echo "Required user '${required_user}' must be created before exiting."
            continue
        fi
        if [[ "$root_password_created" != true ]]; then
            echo "Root password must be set before exiting (or use '.exit-without-root')."
            continue
        fi
        exit 0
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

    if [[ -n "$required_user" && "$username" == "$required_user" ]]; then
        required_user_created=true
    fi
    if [[ "$username" == "root" ]]; then
        root_password_created=true
    fi

    echo "Enter password for $username:"
    # Generate hash and save to passwords/<filename>
    # We save using '<username>+<groups>' so the installer sees the extra groups later
    openssl passwd -6 > "passwords/$filename"
    
    echo "Saved hash for user: $username"
    if [[ -n "$required_user" && "$required_user_created" != true ]]; then
        echo "Required user must be created: ${required_user}"
    fi
    if [[ "$root_password_created" != true ]]; then
        echo "Root password not set yet."
    fi
    echo "Type '.exit' to stop when finished."
done
