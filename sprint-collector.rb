#!/usr/bin/env ruby
require 'optparse'
require 'net/http'
require 'json'

class String
  def bold;           "\e[1m#{self}\e[22m" end
end

# status_id:
# 1 - new
# 5 - closed
# 7 - ready for testing
#
# assigned_to_id
@user_ids = {
  6626 => /Gail|Steiger|gsteiger/i,
  5096 => /Tomer|Brisker|tbrisker/i,
  3517 => /Daniel|Lobato|dlobatog/i,
  6040 => /Amir|Feferkuchen|afeferku/i,
  718 => /Lukas|Zapletal|lzap/i
}

# 118 - team daniel - iteration 1
@target_version = 118

def user_to_id(user)
  # Match user input with any name.
  # e.g: 'lukas' or 'zapletal' would match 'Lukas Zapletal'
  @user_ids.each do |id, name_regex|
    return id.to_s if user =~ /#{name_regex}/i
  end
end

# Gather all IDs for issues on Ready for Testing/Closing
def gather_issues(status_id, options)
  url = "#{options[:url]}/issues.json?status_id=#{status_id}&updated_on=#{options[:date]}" +
    "&assigned_to_id=#{user_to_id(options[:user])}&limit=100"
    puts url
  uri = URI(URI.escape(url))
  response = Net::HTTP.get(uri)
  JSON.parse(response)
end

def modify_target_version!(issue_id, options)
  uri = URI(URI.escape("#{options[:url]}/issues/#{issue_id}.json"))
  req = Net::HTTP::Put.new(uri,
                           { 'Content-Type' => 'application/json',
                             'X-Redmine-API-Key' => File.read('redminekey') })
  req.body = { :issue => { :fixed_version_id => @target_version } }.to_json
  response = Net::HTTP.new(uri.host, uri.port).start {|http| http.request(req) }
  puts response.code
  puts response.body
end

def print_issues(issues, type, options)
  puts
  puts '-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-'
  puts
  puts 'Found a total of: ' + issues['total_count'].to_s.bold + " issues " +
    type.bold + " for #{options[:user].bold}"
  puts issues['issues'].map { |issue| "#{issue['id']} - #{issue['project']['name']} - #{issue['subject']}"  }.join("\n").bold
end


#
# Send PUT request to each issue to modify target version
# X-Redmine-API-Key must contain your API key
# { :fixed_version_id => 118 }
#

options = Hash.new('')

opt_parser = OptionParser.new do |opt|
  opt.banner = "Usage: redmine-sprint-collector [OPTIONS]"
  opt.separator  "Checks for issues on 'ready for testing' and assigns a target version"
  opt.separator  ""

  opt.on("-h","--help","help") do
    puts opt_parser
    exit(0)
  end

  opt.on("-u username","--user username", "Name of person whose issues will be retrieved") do |user|
    options[:user] = user
  end

  opt.on("-p project","--project project", "Projects to look in") do |project|
    options[:project] = project
  end

  opt.on("-t target","--target target", "Target version to set to Ready for testing issues") do |target|
    options[:target] = target
  end

  opt.on("-d date","--date date", "Date to search (updated_on). e.g: ><2016-07-26|2016-08-09") do |date|
    options[:date] = date
  end

  opt.on("--url url", "Redmine URL, e.g: http://example.redmine.org") do |url|
    options[:url] = url
  end
end

opt_parser.parse!

# Enforce the presence of user, target and url
mandatory = [:user, :url, :target, :date]
missing = mandatory.select{ |param| options[param] == '' }
unless missing.empty?
  puts opt_parser
  puts
  raise OptionParser::MissingArgument.new(missing.join(', '))
end

ready_for_testing = gather_issues(7, options)
closed = gather_issues(5, options)
# projects.theforeman.org/issues.json?status_id=7&assigned_to_id=6626&updated_on=><2016-07-26|2016-08-09
#ready_for_testing = JSON.parse(File.read('test_data.json'))

print_issues(ready_for_testing, 'ready for testing', options)
print_issues(closed, 'closed',  options)

ready_for_testing['issues'].each do |issue|
  next if issue['project']['name'] == 'Discovery'
  modify_target_version(issue['id'], options)
end
closed['issues'].each do |issue|
  next if issue['project']['name'] == 'Discovery'
  modify_target_version(issue['id'], options)
end
