# frozen_string_literal: true

require 'rails_helper'
require 'mastodon/cli/main'

describe Mastodon::CLI::Main do
  subject { cli.invoke(action, arguments, options) }

  let(:cli) { described_class.new }
  let(:arguments) { [] }
  let(:options) { {} }

  it_behaves_like 'CLI Command'

  describe '#version' do
    let(:action) { :version }

    it 'returns the Mastodon version' do
      expect { subject }.to output(
        a_string_including(Mastodon::Version.to_s)
      ).to_stdout
    end
  end
end
