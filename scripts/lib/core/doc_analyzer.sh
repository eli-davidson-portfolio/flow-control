#!/bin/bash

# Add a helper function at the top of the file to handle section replacement
replace_section() {
    local file="$1"
    local section="$2"
    local content="$3"
    local temp_file=$(mktemp)
    local in_section=false
    local next_section_found=false

    # Read the file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ $line =~ ^$section$ ]]; then
            # Found the section to replace
            in_section=true
            echo "$line" >> "$temp_file"
            echo -n "$content" >> "$temp_file"
        elif [[ $in_section == true && $line =~ ^##[^#] ]]; then
            # Found the next section
            in_section=false
            next_section_found=true
            echo "$line" >> "$temp_file"
        elif [[ $in_section == false ]]; then
            # Outside the section to replace
            echo "$line" >> "$temp_file"
        fi
    done < "$file"

    # If we were in a section and didn't find a next section, add a newline
    if [[ $in_section == true && $next_section_found == false ]]; then
        echo >> "$temp_file"
    fi

    # If section wasn't found, append it
    if ! grep -q "^$section$" "$file"; then
        echo >> "$temp_file"
        echo "$section" >> "$temp_file"
        echo -n "$content" >> "$temp_file"
        echo >> "$temp_file"
    fi

    mv "$temp_file" "$file"
}

# Documentation Analyzer
analyze_go_mod() {
    if [ -f "go.mod" ]; then
        local content
        content=$'\n### 📦 Dependencies\n\n'
        content+='<details>\n<summary>View Dependencies</summary>\n\n'
        content+='```go\n'
        content+="$(cat go.mod)"
        content+=$'\n```\n'
        content+='</details>\n'
        
        replace_section "$DOC_STATUS_FILE" "## Go Dependencies" "$content"
        return 0
    fi
    return 1
}

analyze_config() {
    if [ -f "scripts/lib/core/config.sh" ]; then
        local content
        content=$'\n### 🔧 Configuration Analysis\n\n'
        content+='> The following functions are defined in the configuration system\n\n'
        
        # Extract and format function documentation
        local seen_functions=""
        while IFS= read -r line; do
            [[ $line =~ ^function[[:space:]]+([a-zA-Z_]+)[[:space:]]*\(\) ]] || continue
            
            func_name="${BASH_REMATCH[1]}"
            [[ $seen_functions == *"|$func_name|"* ]] && continue
            seen_functions+="|$func_name|"
            
            # Get function documentation and implementation
            local func_doc
            func_doc=$(awk -v fn="$func_name" '
                BEGIN { in_func = 0; doc = ""; impl = ""; }
                /^[[:space:]]*#/ && !in_func { 
                    gsub(/^[[:space:]]*#[[:space:]]*/, "");
                    doc = doc $0 "\n";
                    next;
                }
                /^function[[:space:]]+'"$func_name"'\(\)/ { 
                    in_func = 1;
                    impl = "\n<details>\n<summary>View Implementation</summary>\n\n```bash\nfunction " fn "() {\n";
                    next;
                }
                in_func { 
                    if ($0 ~ /^[[:space:]]*[^}]/) {
                        impl = impl "  " $0 "\n";
                    } else {
                        impl = impl $0 "\n";
                    }
                }
                /^}/ && in_func {
                    in_func = 0;
                    impl = impl "```\n</details>\n";
                    print doc impl;
                }
            ' "scripts/lib/core/config.sh")
            
            content+=$'\n'
            content+="#### 📝 \`$func_name\`"$'\n'
            if [ -n "$func_doc" ]; then
                content+="$func_doc"
            else
                content+="_No documentation available._"$'\n\n'
            fi
        done < "scripts/lib/core/config.sh"
        
        replace_section "$DOC_STATUS_FILE" "## Configuration" "$content"
        return 0
    fi
    return 1
}

analyze_project_requirements() {
    if [ -f "project.txt" ]; then
        local content
        content=$'\n### 📋 Project Requirements\n\n'
        content+='> Key requirements and features for the project\n\n'
        local seen_items=""
        
        while IFS= read -r line; do
            # Normalize the line
            line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]\+/ /g')
            
            # Skip empty lines, headers, and duplicates
            [[ -z "$line" || "$line" =~ ^Project[[:space:]]Requirements:?$ || "$seen_items" == *"|$line|"* ]] && continue
            seen_items+="|$line|"
            
            # Handle different line formats
            if [[ $line =~ ^[0-9]+\.[[:space:]](.+) ]]; then
                content+="✨ $line"$'\n'
            elif [[ $line =~ ^-[[:space:]](.+) ]]; then
                content+="$line"$'\n'
            elif [[ $line =~ ^[[:space:]]*[A-Za-z] ]]; then
                content+="- $line"$'\n'
            fi
        done < "project.txt"
        
        replace_section "$DOC_STATUS_FILE" "## Project Requirements" "$content"
        return 0
    fi
    return 1
} 