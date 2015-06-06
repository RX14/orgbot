FROM ruby:2.2.2

WORKDIR /orgbot
ADD . /orgbot

RUN bundle

CMD ["/orgbot/rubybot.rb"]
