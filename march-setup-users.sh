#!/usr/bin/bash

echo "Configuring users from passwords/ directory..."

for hash_file in passwords/*; do
    # 1. Get the raw filename (e.g., "taruna+wheel,samba" or "guest")
    filename=$(basename "$hash_file")
    
    # 2. Extract Username (Remove everything after first '+')
    # If no '+', this remains the full filename
    username="${filename%%+*}"
    
    # 3. Extract Groups (Remove everything before first '+')
    # If no '+', this becomes the full filename (we fix that in the next check)
    groups_suffix="${filename#*+}"
    
    # Check if we actually had a suffix
    if [[ "$filename" == "$groups_suffix" ]]; then
        extra_groups="" 
    else
        extra_groups="$groups_suffix"
    fi

    # Read the hash
    password_hash=$(<"$hash_file")

    if [[ "$username" == "root" ]]; then
        echo "Setting up root password..."
        arch-chroot /mnt usermod -p "$password_hash" root
    else
        echo "Creating user: $username"
        
        # Prepare the useradd command
        # Always use -m (create home) and -g users (primary group)
        cmd=("useradd" "-m" "-g" "users" "-s" "/usr/bin/zsh" "-p" "$password_hash")
        
        # Add supplementary groups if defined (e.g., wheel,samba)
        if [[ -n "$extra_groups" ]]; then
            echo "  -> Adding to groups: $extra_groups"
            cmd+=("-G" "$extra_groups")
        fi
        
        # Check if user exists before adding
        if arch-chroot /mnt id "$username" &>/dev/null; then
             echo "  -> User exists, updating password..."
             arch-chroot /mnt usermod -p "$password_hash" "$username"
             # Also append groups if requested
             if [[ -n "$extra_groups" ]]; then
                arch-chroot /mnt usermod -aG "$extra_groups" "$username"
             fi
        else
            # Execute the constructed array command
            arch-chroot /mnt "${cmd[@]}" "$username"
        fi
    fi
done