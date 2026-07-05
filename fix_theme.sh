#!/bin/bash
sed -i '' 's/- (void)applyInterfaceStyle:(UIUserInterfaceStyle)style toWindow:(UIWindow \*)window;/- (void)applyInterfaceStyleGlobally:(UIUserInterfaceStyle)style;/g' "Pure Pets/DesignFiles/PP/PPStyles/Styling.h"
