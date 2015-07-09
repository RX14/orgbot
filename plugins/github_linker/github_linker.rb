require "gitio"
require "faraday/http_cache"
require "octokit"
require "active_support"

stack = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::HttpCache
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end

Octokit.middleware = stack

class GithubLinker
  include Cinch::Plugin

  def initialize(*args)
    super

    @last = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  end

  Yajl::Parser.parse(File.read("config.json"))["github_linker"].each do |channel, aliases|
    aliases.each do |repo, a2|
      a2 << repo
      a2 << repo.split("/")[1]
      a2.each do |a|
        match /(?:\s|^)#{a}#([0-9]{1,4})(?:\s|$)/i, method: (channel + "/" + a).to_sym, use_prefix: false, use_suffix: false, group: repo.to_sym
        match /(?:\s|^)#{a == "" ? "" : "#{a} "}issue ([0-9]{1,4})(?:\s|$)/i, method: (channel + "/" + a).to_sym, use_prefix: false, use_suffix: false, group: repo.to_sym

        define_method("#{channel}/#{a}") do |m, issue_num|
          if m.target == channel
            puts JSON.pretty_generate(@last)
            @last[channel]["#{repo}##{issue_num}"] = Time.now.advance(days: -1) if @last[channel]["#{repo}##{issue_num}"].is_a? Hash
            if @last[channel]["#{repo}##{issue_num}"] < Time.now.advance(minutes: -5)
              begin
                issue = Octokit.issue repo, issue_num
                m.channel.notice "[#{Format(:pink, repo)} #{Format(:green, "##{issue.number}")}] - #{Gitio.shorten(issue.html_url)} #{issue.user.login}: \"#{issue.title}\""
              rescue Octokit::NotFound
              end
            end
            @last[channel]["#{repo}##{issue_num}"] = Time.now
          end
        end
      end
    end
  end
end
