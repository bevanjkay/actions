# typed: true
# frozen_string_literal: true

# rubocop:disable Style/TopLevelMethodDefinition

require "English"
# typed: true
require "formula"
require "cask"

ONE_YEAR_AGO = (Date.today << 12).freeze
TARGET_TAP = ENV.fetch("GITHUB_REPOSITORY").freeze

def git(*args)
  system "git", *args
  exit $CHILD_STATUS.exitstatus unless $CHILD_STATUS.success?
end

def find_disabled(packages: [])
  packages.select do |package|
    next false if package.tap != TARGET_TAP.path
    next false unless package.disabled?
    next false if package.disable_date.nil?

    puts "#{package.name} is disabled"

    package.disable_date < ONE_YEAR_AGO
  end
end

def sourcefile_path(package)
  package.is_a?(Formula) ? package.path : package.sourcefile_path
end

puts "Finding disabled packages..."

packages_to_remove = find_disabled(packages: Formula.all + Cask::Cask.all)

packages_to_remove.each { |package| FileUtils.rm sourcefile_path(package) }

tap_dir = TARGET_TAP.path

out, err, status = Open3.capture3 "git", "-C", tap_dir.to_s, "status", "--porcelain", "--ignore-submodules=dirty"
raise err unless status.success?

if out.chomp.empty?
  puts "No packages removed."
  File.open(ENV.fetch("GITHUB_OUTPUT", nil), "a") { |f| f.puts("packages-removed=false") }
  exit
end

puts "Removing disabled packages..."

git "-C", tap_dir.to_s, "add", "--all"

packages_to_remove.each do |package|
  puts "Removed `#{package.name}`."
  git "-C", tap_dir.to_s, "commit", sourcefile_path(package), "--message",
      "#{package.name}: remove #{package.is_a?(Formula) ? "formula" : "cask"}", "--quiet"
end

File.open("./output.txt", "a") { |f| f.puts("packages-removed=true") }

# rubocop:enable Style/TopLevelMethodDefinition
