require 'xcodeproj'
project_path = 'MoMoDemoApp/MoMoDemoApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first
group = project.main_group.find_subpath(File.join('MoMoDemoApp'), true)
file_ref = group.new_reference('AppDependencyContainer.swift')
target.add_file_references([file_ref])
project.save
