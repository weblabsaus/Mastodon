# frozen_string_literal: true

require 'rails_helper'
require 'mastodon/cli/preview_cards'

describe Mastodon::CLI::PreviewCards do
  it_behaves_like 'A CLI Sub-Command'
end
