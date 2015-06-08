require File.dirname(__FILE__) + '/../http_server/http_server'
require 'gitio'
require 'cinch/formatting'
require 'cinch/helpers'
require 'yajl'

# noinspection RubyResolve

class Github
  extend Cinch::HttpServer::Verbs
  include Cinch::Plugin

  listen_to :connect, method: :connected

  def connected(_)
  end

  before do
    request.body.rewind
    read = request.body.read

    @request_payload = Yajl::Parser.parse(read, symbolize_keys: true)
  end

  post '/gh-hook', :agent => /GitHub-Hookshot\/.*/ do
    payload = @request_payload
    event   = request.env['HTTP_X_GITHUB_EVENT']
    case event
      when 'pull_request'
        action = payload[:action]
        unless /(un)?labeled/ =~ action
          issue = payload[:number]
          repo  = payload[:repository][:name]
          title = payload[:pull_request][:title]
          url   = Gitio::shorten payload[:pull_request][:html_url]
          user  = payload[:sender][:login]
          bot.bot_config['github_orgs'][payload[:repository][:owner][:login]].map do |it|
            bot.channel_list.find(it)
          end.each do |chan|
            chan.notice "[#{Cinch::Formatting.format(:pink, repo)}]: #{Cinch::Formatting.format(:orange, user)} #{action} pull request #{Cinch::Formatting.format(:green, "\##{issue}")}: \"#{title}\" - #{url}"
          end
        end

      when 'pull_request_review_comment'
        url   = Gitio::shorten payload[:comment][:html_url]
        issue = payload[:pull_request][:number]
        user  = payload[:comment][:user][:login]
        body  = payload[:comment][:body]
        repo  = payload[:repository][:name]
        bot.bot_config['github_orgs'][payload[:repository][:owner][:login]].map do |it|
          bot.channel_list.find(it)
        end.each do |chan|
          chan.notice "[#{Cinch::Formatting.format(:pink, repo)}]: #{Cinch::Formatting.format(:orange, user)} reviewed pull request #{Cinch::Formatting.format(:green, "\##{issue}")} - #{url}"

          body = body.split(/\r\n|\r|\n/)[0]

          split_end = " ..."
          command   = "NOTICE"

          maxlength             = 510 - (":" + " #{command} " + " :").size
          maxlength             = maxlength - bot.mask.to_s.length - chan.name.to_s.length - 2
          maxlength_without_end = maxlength - split_end.bytesize

          if body.bytesize > maxlength
            splitted = []

            if body.bytesize > maxlength_without_end
              pos = body.rindex(/\s/, maxlength_without_end)
              r   = pos || maxlength_without_end
              splitted << body.slice!(0, r) + split_end.tr(" ", "\u00A0")
              body = body.lstrip
            end

            bot.irc.send("#{command} #{chan.name} :\"#{splitted[0].tr("\u00A0", " ")}\"")
          else
            bot.irc.send("#{command} #{chan.name} :\"#{body}\"")
          end
        end

      when 'push'
        branch = payload[:ref]
        branch.slice!(/^refs\/heads\//)
        num  = payload[:commits].length
        repo = payload[:repository][:name]
        url  = Gitio::shorten payload[:compare]
        user = payload[:sender][:login]
        org  = payload[:repository][:owner][:name]

        ignore_branches = bot.bot_config["github_ignore_branches"][payload[:repository][:full_name]] || []

        unless ignore_branches.include? branch

          bot.bot_config['github_orgs'][org].map do |it|
            bot.channel_list.find(it)
          end.each do |chan|
            chan.notice "[#{Cinch::Formatting.format(:pink, repo)}]: #{Cinch::Formatting.format(:orange, user)} pushed #{Cinch::Formatting.format(:green, num.to_s)} commits to #{Cinch::Formatting.format(:green, branch)}: #{url}"
            payload[:commits].take(3).each do |commit|
              chan.notice "[#{Cinch::Formatting.format(:pink, repo)}]: #{Cinch::Formatting::format(:green, commit[:id][0..7])} #{commit[:message].split(/\r\n|\r|\n/)[0]}"
            end
            unless num <= 3
              chan.notice "[#{Cinch::Formatting.format(:pink, repo)}]: ...and #{Cinch::Formatting.format(:green, (num - 3).to_s)} more."
            end
          end
        end

      when 'issues'
        action = payload[:action]
        unless /(un)?labeled/ =~ action
          issue = payload[:issue][:number]
          repo  = payload[:repository][:name]
          title = payload[:issue][:title]
          url   = Gitio::shorten payload[:issue][:html_url]
          user  = payload[:sender][:login]

          unless payload[:assignee].nil?
            a2 = case action
                   when "assigned"
                     "to"
                   when "unassigned"
                     "from"
                 end

            if payload[:assignee][:login] == user
              extra = " #{a2} themselves"
            else
              extra = " #{a2} #{payload[:assignee][:login]}"
            end
          end

          bot.bot_config['github_orgs'][payload[:repository][:owner][:login]].map do |it|
            bot.channel_list.find(it)
          end.each do |chan|
            chan.notice "[#{Cinch::Formatting.format(:pink, repo)}]: #{Cinch::Formatting.format(:orange, user)} #{action} issue #{Cinch::Formatting.format(:green, "\##{issue}")}#{extra}: \"#{title}\" - #{url}"
          end
        end

      when 'issue_comment'
        url   = Gitio::shorten payload[:issue][:html_url]
        issue = payload[:issue][:number]
        user  = payload[:comment][:user][:login]
        body  = payload[:comment][:body]
        title = payload[:issue][:title]
        repo  = payload[:repository][:name]
        bot.bot_config['github_orgs'][payload[:repository][:owner][:login]].map do |it|
          bot.channel_list.find(it)
        end.each do |chan|
          chan.notice "[#{Cinch::Formatting.format(:pink, repo)}]: #{Cinch::Formatting.format(:orange, user)} commented on issue #{Cinch::Formatting.format(:green, "\##{issue}")}: \"#{title}\" - #{url}"

          body = body.split(/\r\n|\r|\n/)[0]

          split_end = " ..."
          command   = "NOTICE"

          maxlength             = 510 - (":" + " #{command} " + " :").size
          maxlength             = maxlength - bot.mask.to_s.length - chan.name.to_s.length - 2
          maxlength_without_end = maxlength - split_end.bytesize

          if body.bytesize > maxlength
            splitted = []

            if body.bytesize > maxlength_without_end
              pos = body.rindex(/\s/, maxlength_without_end)
              r   = pos || maxlength_without_end
              splitted << body.slice!(0, r) + split_end.tr(" ", "\u00A0")
              body = body.lstrip
            end

            bot.irc.send("#{command} #{chan.name} :\"#{splitted[0].tr("\u00A0", " ")}\"")
          else
            bot.irc.send("#{command} #{chan.name} :\"#{body}\"")
          end
        end

      when 'create'
        branch = payload[:ref]
        type   = payload[:ref_type]
        repo   = payload[:repository][:name]
        url    = Gitio::shorten payload[:repository][:html_url]
        user   = payload[:sender][:login]
        bot.bot_config['github_orgs'][payload[:repository][:owner][:login]].map do |it|
          bot.channel_list.find(it)
        end.each do |chan|
          chan.notice "[#{Cinch::Formatting.format(:pink, repo)}]: #{Cinch::Formatting.format(:orange, user)} created #{type} #{branch}: #{url}"
        end

      when 'delete'
        branch = payload[:ref]
        type   = payload[:ref_type]
        repo   = payload[:repository][:name]
        url    = Gitio::shorten payload[:repository][:html_url]
        user   = payload[:sender][:login]
        bot.bot_config['github_orgs'][payload[:repository][:owner][:login]].map do |it|
          bot.channel_list.find(it)
        end.each do |chan|
          chan.notice "[#{Cinch::Formatting.format(:pink, repo)}]: #{Cinch::Formatting.format(:orange, user)} deleted #{type} #{branch}: #{url}"
        end

      when 'fork'
        repo = payload[:repository][:name]
        url  = Gitio::shorten payload[:forkee][:html_url]
        user = payload[:forkee][:owner][:login]
        bot.bot_config['github_orgs'][payload[:repository][:owner][:login]].map do |it|
          bot.channel_list.find(it)
        end.each do |chan|
          chan.notice "[#{Cinch::Formatting.format(:pink, repo)}]: #{Cinch::Formatting.format(:orange, user)} forked the repo: #{url}"
        end

      when 'commit_comment'
        url    = Gitio::shorten payload[:comment][:html_url]
        commit = payload[:comment][:commit_id]
        user   = payload[:comment][:user][:login]
        body   = payload[:comment][:body]
        repo   = payload[:repository][:name]
        bot.bot_config['github_orgs'][payload[:repository][:owner][:login]].map do |it|
          bot.channel_list.find(it)
        end.each do |chan|
          chan.notice "[#{Cinch::Formatting.format(:pink, repo)}]: #{Cinch::Formatting.format(:orange, user)} commented on commit #{Cinch::Formatting.format(:green, commit)}: #{url}"

          body = body.split(/\r\n|\r|\n/)[0]

          split_end = " ..."
          command   = "NOTICE"

          maxlength             = 510 - (":" + " #{command} " + " :").size
          maxlength             = maxlength - bot.mask.to_s.length - chan.name.to_s.length - 2
          maxlength_without_end = maxlength - split_end.bytesize

          if body.bytesize > maxlength
            splitted = []

            if body.bytesize > maxlength_without_end
              pos = body.rindex(/\s/, maxlength_without_end)
              r   = pos || maxlength_without_end
              splitted << body.slice!(0, r) + split_end.tr(" ", "\u00A0")
              body = body.lstrip
            end

            bot.irc.send("#{command} #{chan.name} :\"#{splitted[0].tr("\u00A0", " ")}\"")
          else
            bot.irc.send("#{command} #{chan.name} :\"#{body}\"")
          end
        end

      when 'status'
        state = payload[:state]
        unless state == 'pending'
          repo = payload[:repository][:name]
          url  = payload[:target_url]
          desc = payload[:description]


          bot.loggers.info $statuses.inspect

          $statuses = {} if $statuses.nil?

          old_state = $statuses[payload[:repository][:full_name]] || state

          if old_state != state
            state_transition = "#{old_state} -> #{state}"
            case state_transition
              when "success -> failure", "success -> error"
                state = "broken"
              when "failure -> success", "error -> success"
                state = "fixed"
            end
            state_transition = " (#{state_transition})"
          end

          bot.bot_config['github_orgs'][payload[:repository][:owner][:login]].map do |it|
            bot.channel_list.find(it)
          end.each do |chan|
            chan.notice "[#{Cinch::Formatting.format(:pink, repo)}]: #{desc} - #{url}#{state_transition}"

            if state == "broken"
              chan.notice "GOD DAMNIT #{payload[:commit][:author][:login].upcase}! YOU BROKE THE BUILD!"
            end
          end

          $statuses[payload[:repository][:full_name]] = payload[:state]
        end
      else
        # No-op
    end
    204
  end
end
