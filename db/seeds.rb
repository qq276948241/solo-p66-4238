School.create!(name: '北京大学', email_suffix: 'pku.edu.cn')
School.create!(name: '清华大学', email_suffix: 'tsinghua.edu.cn')
School.create!(name: '复旦大学', email_suffix: 'fudan.edu.cn')
School.create!(name: '浙江大学', email_suffix: 'zju.edu.cn')

puts "已创建 #{School.count} 所学校"
