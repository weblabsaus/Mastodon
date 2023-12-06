# frozen_string_literal: true

require 'rails_helper'
require 'mastodon/cli/upgrade'

describe Mastodon::CLI::Upgrade do
  subject { cli.invoke(action, arguments, options) }

  let(:cli) { described_class.new }
  let(:arguments) { [] }
  let(:options) { {} }

  it_behaves_like 'CLI Command'

  describe '#storage_schema' do
    let(:action) { :storage_schema }

    context 'with records that dont need upgrading' do
      before do
        Fabricate(:account)
        Fabricate(:media_attachment)
      end

      it 'does not upgrade storage for the attachments' do
        expect { subject }.to output(
          a_string_including('Upgraded storage schema of 0 records')
        ).to_stdout
      end
    end
  end
end
