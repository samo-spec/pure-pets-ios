import sys
from pbxproj import XcodeProject

project_path = '/Users/mohammedahmed/Desktop/PurePets/PurePetsProjects/Pure Pets IOS/Pure Pets.xcodeproj/project.pbxproj'
project = XcodeProject.load(project_path)

file_h = 'Pure Pets/MainApp/GEMENI/PPNovaGenkitService.h'
file_m = 'Pure Pets/MainApp/GEMENI/PPNovaGenkitService.m'

project.add_file(file_h, target_name='Pure Pets')
project.add_file(file_m, target_name='Pure Pets')

project.save()
print("Added files to project.")
