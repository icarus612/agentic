import os

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

files_to_check = []
for root, dirs, files in os.walk('.'):
    if any(ignore in root for ignore in ['.git', 'node_modules', '.workflows', 'project-plans/completed', 'project-plans/proposals']):
        continue
    for file in files:
        if file.endswith('.md'):
            files_to_check.append(os.path.join(root, file))

replacements = [
    ('Agent tool', 'Agent/invoke_subagent tool'),
    ('Bash tool', 'Bash/run_command tool'),
    ('Bash call', 'Bash/run_command call'),
    ('Bash hooks', 'Bash/run_command hooks')
]

for filepath in files_to_check:
    replace_in_file(filepath, replacements)
