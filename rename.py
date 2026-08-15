import os
import glob

def replace_in_file(filepath, replacements):
    with open(filepath, 'r') as f:
        content = f.read()
    
    new_content = content
    for old, new in replacements:
        new_content = new_content.replace(old, new)
        
    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

# Find all markdown and shell files (ignoring node_modules, .git, etc.)
files_to_check = []
for root, dirs, files in os.walk('.'):
    if any(ignore in root for ignore in ['.git', 'node_modules', '.workflows', 'project-plans/completed', 'project-plans/proposals']):
        continue
    for file in files:
        if file.endswith('.md') or file.endswith('.sh') or file.endswith('.json'):
            files_to_check.append(os.path.join(root, file))

replacements = [
    ('generic/', 'agent-agnostic/'),
    ('claude/', 'agent-specific/claude/'),
    ('antigravity/', 'agent-specific/antigravity/'),
    ('generic}', 'agent-agnostic}'),
    ('claude}', 'agent-specific/claude}'),
    ('antigravity}', 'agent-specific/antigravity}')
]

# Specifically for AGENTS.md, we don't want to replace "antigravity (" or things like that, just paths.
# The simple string replacement above works since it includes the trailing slash.

for filepath in files_to_check:
    if filepath == './rename.py': continue
    replace_in_file(filepath, replacements)
