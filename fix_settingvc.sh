#!/bin/bash
cat << 'INNER_EOF' > /tmp/settingvc_patch.py
import re

with open("Pure Pets/MainApp/UserFiles/SettingVC.m", "r") as f:
    content = f.read()

# We need to find the corrupted block in pp_applyThemeAtIndex:
pattern = re.compile(r'\[\[NSUserDefaults standardUserDefaults\] setBool:YES forKey:@"PPThemeUserChos.*?\}ct:nil\];\n    \}', re.DOTALL)
replacement = """[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PPThemeUserChoseExplicitly"];
    [[PPThemeManager sharedManager] applyInterfaceStyleGlobally:style];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PPThemePreferenceDidChangeNotification object:nil];
    });
}"""

content = pattern.sub(replacement, content)

with open("Pure Pets/MainApp/UserFiles/SettingVC.m", "w") as f:
    f.write(content)

INNER_EOF
python3 /tmp/settingvc_patch.py
