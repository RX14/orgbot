require "gitio"
require "faraday/http_cache"
require "octokit"

stack              = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::HttpCache
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end
Octokit.middleware = stack

class GithubLinker
  include Cinch::Plugin

  Yajl::Parser.parse(File.read("config.json"))["github_linker"].each do |channel, aliases|
    aliases.each do |repo, a2|
      a2 << repo
      a2 << repo.split("/")[1]
      a2.each do |a|
        GithubLinker.match /(?:\s|^)#{a}#([0-9]{1,4})(?:\s|$)/i, method: (channel + "/" + a).to_sym, use_prefix: false, use_suffix: false

        GithubLinker.send :define_method, channel + "/" + a do |m, issue|
          if m.target == channel
            begin
              issue = Octokit.issue repo, issue
              m.reply "[#{Format(:pink, repo)} #{Format(:green, "##{issue.number}")}] - #{Gitio.shorten(issue.html_url)} #{issue.user.login}: \"#{issue.title}\""
            rescue Octokit::NotFound
            end
          end
        end
      end
    end
  end
end
