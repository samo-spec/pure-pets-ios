#!/bin/bash
cat << 'INNER_EOF' > /tmp/company_patch_3.py
with open("Pure Pets/MainApp/Helpers/CompanyLocationVC.m", "r") as f:
    content = f.read()

# 1. Remove markerView from pp_prepareEntranceStateIfNeeded
bad_prepare = """    self.topGlowView.alpha = [self pp_reduceMotionEnabled] ? 1.0 : 0.0;
    self.bottomGlowView.alpha = [self pp_reduceMotionEnabled] ? 1.0 : 0.0;
    self.markerView.alpha = [self pp_reduceMotionEnabled] ? 1.0 : 0.0;
    self.markerView.transform = [self pp_reduceMotionEnabled] ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.92, 0.92);"""
good_prepare = """    self.topGlowView.alpha = [self pp_reduceMotionEnabled] ? 1.0 : 0.0;
    self.bottomGlowView.alpha = [self pp_reduceMotionEnabled] ? 1.0 : 0.0;"""
content = content.replace(bad_prepare, good_prepare)

# 2. Remove markerView from didRunEntrance block
bad_reduce = """    if ([self pp_reduceMotionEnabled]) {
        self.sheetView.alpha = 1.0;
        self.markerView.alpha = 1.0;
        self.topGlowView.alpha = 1.0;
        self.bottomGlowView.alpha = 1.0;
        return;
    }"""
good_reduce = """    if ([self pp_reduceMotionEnabled]) {
        self.sheetView.alpha = 1.0;
        self.topGlowView.alpha = 1.0;
        self.bottomGlowView.alpha = 1.0;
        return;
    }"""
content = content.replace(bad_reduce, good_reduce)

# 3. Remove markerView float animation from pp_applyAmbientMotionIfNeeded
bad_ambient_early = """        [self.markerView.layer removeAnimationForKey:@"pp.location.marker.float"];"""
content = content.replace(bad_ambient_early, "")

bad_ambient_add = """    if (self.markerView && ![self.markerView.layer animationForKey:@"pp.location.marker.float"]) {
        CABasicAnimation *markerFloat = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        markerFloat.fromValue = @0.0;
        markerFloat.toValue = @(-5.0);
        markerFloat.duration = 3.2;
        markerFloat.autoreverses = YES;
        markerFloat.repeatCount = HUGE_VALF;
        markerFloat.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.markerView.layer addAnimation:markerFloat forKey:@"pp.location.marker.float"];
    }"""
content = content.replace(bad_ambient_add, "")

with open("Pure Pets/MainApp/Helpers/CompanyLocationVC.m", "w") as f:
    f.write(content)
INNER_EOF
python3 /tmp/company_patch_3.py
