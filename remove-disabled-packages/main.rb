require 'formula'
require 'cask'


one_year_ago = Date.today << 12

def git(*args)
  system 'git', *args
  exit $?.exitstatus unless $?.success?
end

def find_disabled(packages: [])
  packages.select do |package|
    next false unless package.disabled?
    next false if package.disable_date.nil?

    package.disable_date < one_year_ago
  end
end

puts 'Finding disabled packages...'

packages_to_remove = find_disabled(packages: Formula.installed + Cask::Caskroom.casks)

packages_to_remove.each { |package| FileUtils.rm package.path }

tap_dir = Tap.fetch(ENV.fetch("GITHUB_REPOSITORY")).path

out, err, status = Open3.capture3 'git', '-C', tap_dir.to_s, 'status', '--porcelain', '--ignore-submodules=dirty'
raise err unless status.success?

if out.chomp.empty?
  puts 'No packages removed.'
  File.open(ENV['GITHUB_OUTPUT'], 'a') { |f| f.puts('packages-removed=false') }
  exit
end

git '-C', tap_dir.to_s, 'add', '--all'

packages_to_remove.each do |package|
  puts "Removed `#{package.name}`."
  git '-C', tap_dir.to_s, 'commit', package.path.to_s, '--message', "#{package.name}: remove #{package.is_a?(Formula) ? 'formula' : 'cask'}", '--quiet'
end

File.open(ENV['GITHUB_OUTPUT'], 'a') { |f| f.puts('packages-removed=true') }
