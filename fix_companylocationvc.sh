#!/bin/bash
cat << 'INNER_EOF' > /tmp/company_patch.py
with open("Pure Pets/MainApp/Helpers/CompanyLocationVC.m", "r") as f:
    content = f.read()

# 1. Remove glowView from pp_makeMarkerView
glow_view_pattern = """    UIView *glowView = [[UIView alloc] initWithFrame:CGRectMake(50.0, 48.0, 54.0, 54.0)];
    glowView.backgroundColor = [PPLocationAccentColor() colorWithAlphaComponent:0.14];
    PPLocationApplyCornerRadius(glowView, 27.0);
    [container addSubview:glowView];

"""
content = content.replace(glow_view_pattern, "")

# 2. Fix the insertSubview belowSubview:glowView which will now crash because glowView is removed
insert_subview_pattern = """    [container insertSubview:shadowDot belowSubview:glowView];"""
insert_subview_replacement = """    [container insertSubview:shadowDot atIndex:0];"""
content = content.replace(insert_subview_pattern, insert_subview_replacement)

# 3. Remove self.markerView alpha and transform animations from pp_runEntranceIfNeeded to remove the pop fade glitch since GMSMarker tracks changes natively anyway, animating a detached view isn't what they want.
marker_view_anim_pattern = """        self.markerView.alpha = 1.0;
        self.markerView.transform = CGAffineTransformIdentity;"""
content = content.replace(marker_view_anim_pattern, "")

with open("Pure Pets/MainApp/Helpers/CompanyLocationVC.m", "w") as f:
    f.write(content)

INNER_EOF
python3 /tmp/company_patch.py
