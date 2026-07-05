#!/bin/bash
cat << 'INNER_EOF' > /tmp/settingvc_patch_2.py
with open("Pure Pets/MainApp/UserFiles/SettingVC.m", "r") as f:
    content = f.read()

bad_block = """    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PPThemePreferenceDidChangeNotification object:nil];
    });
}
    [self pp_buildSections];"""

good_block = """    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PPThemePreferenceDidChangeNotification object:nil];
    });
    
    [self pp_buildSections];"""

content = content.replace(bad_block, good_block)

with open("Pure Pets/MainApp/UserFiles/SettingVC.m", "w") as f:
    f.write(content)
INNER_EOF
python3 /tmp/settingvc_patch_2.py
