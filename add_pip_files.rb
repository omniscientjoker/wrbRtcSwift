#!/usr/bin/env ruby
require 'xcodeproj'

# 打开项目
project_path = 'SimpleEyes.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 获取主 target
target = project.targets.first

# 查找 Services 组
services_group = project.main_group.find_subpath('SimpleEyes/Services', true)

# 要添加的文件
files_to_add = [
  'SimpleEyes/Services/PictureInPictureManager.swift',
  'SimpleEyes/Services/WebRTCPiPVideoRenderer.swift'
]

files_to_add.each do |file_path|
  # 检查文件是否已经存在于项目中
  existing_file = project.files.find { |f| f.path == file_path || f.real_path.to_s.end_with?(File.basename(file_path)) }

  if existing_file
    puts "文件已存在于项目中: #{file_path}"
  else
    # 添加文件引用到 Services 组
    file_ref = services_group.new_reference(file_path)

    # 添加文件到编译阶段
    target.add_file_references([file_ref])

    puts "已添加文件: #{file_path}"
  end
end

# 保存项目
project.save

puts "完成！请重新打开 Xcode 项目。"
