# frozen_string_literal: true

require 'rails_helper'
require 'mastodon/cli/maintenance'

describe Mastodon::CLI::Maintenance do
  subject { cli.invoke(action, arguments, options) }

  let(:cli) { described_class.new }
  let(:arguments) { [] }
  let(:options) { {} }

  it_behaves_like 'CLI Command'

  describe '#fix_duplicates' do
    let(:action) { :fix_duplicates }

    context 'when the database version is too old' do
      before do
        allow(ActiveRecord::Migrator).to receive(:current_version).and_return(2000_01_01_000000) # Earlier than minimum
      end

      it 'Exits with error message' do
        expect { subject }
          .to output_results('is too old')
          .and raise_error(SystemExit)
      end
    end

    context 'when the database version is too new and the user does not continue' do
      before do
        allow(ActiveRecord::Migrator).to receive(:current_version).and_return(2100_01_01_000000) # Later than maximum
        allow(cli.shell).to receive(:yes?).with('Continue anyway? (Yes/No)').and_return(false).once
      end

      it 'Exits with error message' do
        expect { subject }
          .to output_results('more recent')
          .and raise_error(SystemExit)
      end
    end

    context 'when Sidekiq is running' do
      before do
        allow(ActiveRecord::Migrator).to receive(:current_version).and_return(2022_01_01_000000) # Higher than minimum, lower than maximum
        allow(Sidekiq::ProcessSet).to receive(:new).and_return [:process]
      end

      it 'Exits with error message' do
        expect { subject }
          .to output_results('Sidekiq is running')
          .and raise_error(SystemExit)
      end
    end

    context 'when requirements are met' do
      before do
        prepare_duplicate_data
        allow(ActiveRecord::Migrator).to receive(:current_version).and_return(2023_08_22_081029) # The latest migration before the cutoff
        allow(Sidekiq::ProcessSet).to receive(:new).and_return []
        agree_to_backup_warning
      end

      it 'runs the deduplication process' do
        expect { subject }
          .to output_results(
            'will take a long time',
            'Deduplicating accounts',
            'Restoring index_accounts_on_username_and_domain_lower',
            'Reindexing textual indexes on accounts…',
            'Finished!'
          )
          .and change(duplicate_accounts, :count).from(2).to(1)
      end

      def duplicate_accounts
        Account.where(username: 'one', domain: 'host.example')
      end

      def prepare_duplicate_data
        ActiveRecord::Base.connection.remove_index :accounts, name: :index_accounts_on_username_and_domain_lower
        Fabricate(:account, username: 'one', domain: 'host.example')
        Fabricate.build(:account, username: 'one', domain: 'host.example').save(validate: false)
      end

      def agree_to_backup_warning
        allow(cli.shell)
          .to receive(:yes?)
          .with('Continue? (Yes/No)')
          .and_return(true)
          .once
      end
    end
  end
end
