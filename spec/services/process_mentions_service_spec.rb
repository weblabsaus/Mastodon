require 'rails_helper'

RSpec.describe ProcessMentionsService, type: :service do
  let(:account)    { Fabricate(:account, username: 'alice') }
  let(:visibility) { :public }
  let(:status)     { Fabricate(:status, account: account, text: "Hello @#{remote_user.acct}", visibility: visibility) }

  context 'OStatus with public toot' do
    let(:remote_user) { Fabricate(:account, username: 'remote_user', protocol: :ostatus, domain: 'example.com', salmon_url: 'http://salmon.example.com') }

    subject { ProcessMentionsService.new }

    before do
      stub_request(:post, remote_user.salmon_url)
      subject.call(status)
    end

    it 'does not create a mention' do
      expect(remote_user.mentions.where(status: status).count).to eq 0
    end
  end

  context 'OStatus with private toot' do
    let(:visibility)  { :private }
    let(:remote_user) { Fabricate(:account, username: 'remote_user', protocol: :ostatus, domain: 'example.com', salmon_url: 'http://salmon.example.com') }

    subject { ProcessMentionsService.new }

    before do
      stub_request(:post, remote_user.salmon_url)
      subject.call(status)
    end

    it 'does not create a mention' do
      expect(remote_user.mentions.where(status: status).count).to eq 0
    end

    it 'does not post to remote user\'s Salmon end point' do
      expect(a_request(:post, remote_user.salmon_url)).to_not have_been_made
    end
  end

  context 'ActivityPub' do
    let(:remote_user) { Fabricate(:account, username: 'remote_user', protocol: :activitypub, domain: 'example.com', inbox_url: 'http://example.com/inbox') }

    subject { ProcessMentionsService.new }

    before do
      stub_request(:post, remote_user.inbox_url)
      subject.call(status)
    end

    it 'creates a mention' do
      expect(remote_user.mentions.where(status: status).count).to eq 1
    end

    it 'sends activity to the inbox' do
      expect(a_request(:post, remote_user.inbox_url)).to have_been_made.once
    end
  end

  context 'Enycrypted status' do
    let(:remote_user) { Fabricate(:account, username: 'remote_user', protocol: :activitypub, domain: 'example.com', inbox_url: 'http://example.com/inbox') }
    let(:recipient) { Fabricate(:user) }
    let(:encrypted_status)     { Fabricate(:status, account: account, text: "base64-encrypted-status", visibility: :public, encrypted: true) }

    subject { ProcessMentionsService.new }

    it 'kicks a local notification worker' do
      expect(recipient.account).to be_local
      subject.call(encrypted_status, {usernames: [recipient.account.username]} )
      expect(encrypted_status.mentions[0].account_id).to eq recipient.account.id
      # TODO: write the assertion here!
    end
  end

  context 'Temporarily-unreachable ActivityPub user' do
    let(:remote_user) { Fabricate(:account, username: 'remote_user', protocol: :activitypub, domain: 'example.com', inbox_url: 'http://example.com/inbox', last_webfingered_at: nil) }

    subject { ProcessMentionsService.new }

    before do
      stub_request(:get, "https://example.com/.well-known/host-meta").to_return(status: 404)
      stub_request(:get, "https://example.com/.well-known/webfinger?resource=acct:remote_user@example.com").to_return(status: 500)
      stub_request(:post, remote_user.inbox_url)
      subject.call(status)
    end

    it 'creates a mention' do
      expect(remote_user.mentions.where(status: status).count).to eq 1
    end

    it 'sends activity to the inbox' do
      expect(a_request(:post, remote_user.inbox_url)).to have_been_made.once
    end
  end
end
