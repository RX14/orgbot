# Rubybot

The ninth iteration of the ElrosBot project.

## Installation

Clone the repo

## Usage

From within the project directory, run

`bundle exec ruby rubybot.rb`

## Contributing

1. Fork it ( https://github.com/robotbrain/rubybot/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Example config file
```json
{
  "owner": "######",
  "bot": {
    "server": "irc.esper.net",
    "channels": [
      "#example"
    ],
    "nick": "#######",
    "realname": "#######",
    "sasl.username": "######",
    "sasl.password": "######",
    "user": "ElrosGem"
  },
  "github_orgs": {
    "organisation_name": ["#example"]
  },
  "github_linker": {
    "ORG/REPO": [ //Automatic alias for ORG/REPO and REPO
      "alias" //alias#1
      "" //For just #1
    ],
    "ORG/REPO2": [
      "repo2" //alias#1
    ]
  }
}
```
