# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UnallowDomainService, type: :service do
  subject { described_class.new }

  let(:bad_domain) { 'evil.org' }
  let!(:bad_account) { Fabricate(:account, username: 'badguy666', domain: bad_domain) }
  let!(:bad_status_harassment) { Fabricate(:status, account: bad_account, text: 'You suck') }
  let!(:bad_status_mean) { Fabricate(:status, account: bad_account, text: 'Hahaha') }
  let!(:bad_attachment) { Fabricate(:media_attachment, account: bad_account, status: bad_status_mean, file: attachment_fixture('attachment.jpg')) }
  let!(:already_banned_account) { Fabricate(:account, username: 'badguy', domain: bad_domain, suspended: true, silenced: true) }
  let!(:domain_allow) { Fabricate(:domain_allow, domain: bad_domain) }

  context 'with limited federation mode', :sidekiq_inline do
    before do
      allow(Rails.configuration.x).to receive(:limited_federation_mode).and_return(true)
    end

    describe '#call' do
      before do
        subject.call(domain_allow)
      end

      it 'makes the domain not allowed and removes accounts from that domain' do
        expect(bad_domain_allowed).to be false
        expect(bad_domain_account_exists).to be false

        expect { already_banned_account.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { bad_status_harassment.reload }.to raise_exception ActiveRecord::RecordNotFound
        expect { bad_status_mean.reload }.to raise_exception ActiveRecord::RecordNotFound
        expect { bad_attachment.reload }.to raise_exception ActiveRecord::RecordNotFound
      end
    end
  end

  context 'without limited federation mode' do
    before do
      allow(Rails.configuration.x).to receive(:limited_federation_mode).and_return(false)
    end

    describe '#call' do
      before do
        subject.call(domain_allow)
      end

      it 'makes the domain not allowed but preserves accounts from the domain' do
        expect(bad_domain_allowed).to be false
        expect(bad_domain_account_exists).to be true

        expect { bad_status_harassment.reload }.to_not raise_error
        expect { bad_status_mean.reload }.to_not raise_error
        expect { bad_attachment.reload }.to_not raise_error
      end
    end
  end

  def bad_domain_allowed
    DomainAllow.allowed?(bad_domain)
  end

  def bad_domain_account_exists
    Account.exists?(domain: bad_domain)
  end
end
